"""Read-only camera audit against every authored visible OBB, not CanQuery.

An OBB expanded by the 0.85-stud lens radius conservatively bounds the exact
sphere sweep. Includes decorative leaves/branches even with CanQuery=false.
This checks geometry; native lens behaviour and composition need Studio QA.
"""
from pathlib import Path
from test_paths import ROOT, QA, LUAU, LUAU_COMPILE, TESTS
import hashlib
import json
import math
import re
import sys

sys.path.insert(0,str(ROOT/'tools'))
import world

def add(a,b):return tuple(x+y for x,y in zip(a,b))
def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def mul(a,k):return tuple(x*k for x in a)
def norm(a):return math.sqrt(sum(x*x for x in a))
def lerp(a,b,t):return add(a,mul(sub(b,a),t))
def smooth(t):return t*t*(3-2*t)

def parts(root):
    result=[]
    def walk(node,path):
        p=node.find('Properties')
        name=p.find("string[@name='Name']").text
        path=path+'/'+name
        if node.attrib['class'] in ('Part','SpawnLocation'):
            transparency=p.find("float[@name='Transparency']")
            if transparency is not None and float(transparency.text)>=.95:return
            cf=p.find("CoordinateFrame[@name='CFrame']");size=p.find("Vector3[@name='size']")
            matrix=tuple(tuple(float(cf.find(f'R{i}{j}').text) for j in range(3)) for i in range(3))
            dimensions=tuple(float(size.find(k).text) for k in ('X','Y','Z'))
            result.append(dict(path=path,name=name,position=tuple(float(cf.find(k).text) for k in ('X','Y','Z')),
                matrix=matrix,size=dimensions,
                box_extent=tuple(sum(abs(matrix[i][j])*dimensions[j]/2 for j in range(3)) for i in range(3)),
                radius_scale=tuple(sum(abs(matrix[i][j]) for j in range(3)) for i in range(3)),
                query=p.find("bool[@name='CanQuery']").text=='true'))
        for child in node.findall('Item'):walk(child,path)
    walk(root,'')
    return result

def local(part,position):
    delta=sub(position,part['position']);m=part['matrix']
    return tuple(sum(m[i][j]*delta[i] for i in range(3)) for j in range(3))

def hit(part,a,b,radius):
    # Cheap world-space broad phase; most stage geometry lies far above this
    # reveal. Bounds also cover the expanded OBB, so no blocker is discarded.
    for axis in range(3):
        extent=part['box_extent'][axis]+radius*part['radius_scale'][axis]
        if part['position'][axis]+extent<min(a[axis],b[axis]) or part['position'][axis]-extent>max(a[axis],b[axis]):return None
    a,b=local(part,a),local(part,b);direction=sub(b,a);lo,hi=0.,1.
    for p,d,size in zip(a,direction,part['size']):
        extent=size/2+radius
        if abs(d)<1e-10:
            if abs(p)>extent:return None
        else:
            entry,leave=(-extent-p)/d,(extent-p)/d
            if entry>leave:entry,leave=leave,entry
            lo,hi=max(lo,entry),min(hi,leave)
            if lo>hi:return None
    return lo

def hits(geometry,a,b,radius):
    result=[]
    for part in geometry:
        amount=hit(part,a,b,radius)
        if amount is not None:result.append((amount,part['path']))
    return sorted(result)

def inspect():
    client_bytes=(ROOT/'src/client/DasherClient.client.luau').read_bytes()
    client=client_bytes.decode('utf-8')
    radius=float(re.search(r'mapIntroCamera\s*=\s*\{radius\s*=\s*([.\d]+)',client).group(1))
    def authored(which):
        m=re.search(r'local '+which+r'=start.Position-forward\*([.\d]+)\+right\*\(side\*([.\d]+)\)\+Vector3.new\(0,([.\d]+),0\)',client)
        assert m,('Unable to bind authored camera formula',which)
        return tuple(map(float,m.groups()))
    from_distance,from_side,from_y=authored('from')
    to_distance,to_side,to_y=authored('to')
    report=dict(passed=True,lens_radius=radius,conservative='Visible oriented boxes expanded by the lens radius. Includes CanQuery=false decoration.',
        source_sha256=hashlib.sha256(client_bytes).hexdigest(),
        validation_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        world_sha256=hashlib.sha256((ROOT/'tools/world.py').read_bytes()).hexdigest(),courses={})
    for theme in world.THEMES:
        model=world.build_course(theme);data=world.COURSE_METADATA[theme];geometry=parts(model)
        start=data['start'];p1=data['route'][1]
        forward=(p1['x'],0,p1['z']);forward=mul(forward,1/norm(forward));right=(-forward[2],0,forward[0])
        focus=tuple(sum((p['x'],p['top']+3.5,p['z'])[i] for p in data['route'][1:5])/4 for i in range(3))
        variants=[];selected=None
        for side in (1,-1,0):
            begin=add(add(start,mul(forward,-from_distance)),add(mul(right,side*from_side),(0,from_y,0)))
            end=add(add(start,mul(forward,-to_distance)),add(mul(right,side*to_side),(0,to_y,0)))
            problems=[];previous=None
            for step in range(49):
                position=lerp(begin,end,step/48)
                for check,a,b in [('focus',focus,position),('lens',position,position)]+([('sweep',previous,position)] if previous else []):
                    found=hits(geometry,a,b,radius)
                    if found:problems.append(dict(step=step,check=check,blocker=found[0][1]))
                previous=position
            variants.append(dict(side=side,clear=not problems,from_position=begin,to_position=end,problems=problems[:5]))
            if not problems and selected is None:selected=(side,begin,end)
        old_problems=[]
        old_focus=(0,start[1]+min((data['finish'][1]-start[1])*.4,64),0)
        old_from=(72,start[1]+54,92);old_to=(46,start[1]+34,64)
        for step in range(49):
            position=lerp(old_from,old_to,step/48)
            walls=[p for p in geometry if p['name'].startswith('WallBand')]
            found=hits(walls,old_focus,position,0)
            if found:old_problems.append(dict(step=step,blocker=found[0][1]))
        handoffs=[]
        if selected:
            side,begin,end=selected
            for spawn_z in (-4,4):
                for spawn_x in (-8,-4,0,4,8):
                    root=(spawn_x,26,spawn_z);target=add(add(root,mul(forward,-18)),(0,9,0));target_focus=add(root,(0,2,0))
                    problems=[];previous=None
                    for step in range(121):
                        alpha=step/120;position=lerp(begin,end,smooth(alpha));look=focus
                        if alpha>.72:
                            handoff=smooth(min(1,(alpha-.72)/.28));position=lerp(position,target,handoff);look=lerp(focus,target_focus,handoff)
                        for check,a,b in [('focus',look,position),('lens',position,position)]+([('sweep',previous,position)] if previous else []):
                            found=hits(geometry,a,b,radius)
                            if found:problems.append(dict(step=step,check=check,blocker=found[0][1]))
                        previous=position
                    handoffs.append(dict(spawn=root,clear=not problems,problems=problems[:4]))
        item=dict(visible_parts=len(geometry),nonquery_visible_parts=sum(not p['query'] for p in geometry),
            old_outside_radius=norm((old_from[0],0,old_from[2])),old_wall_blocked_samples=len(old_problems),old_sample_count=49,
            variants=variants,selected_side=selected[0] if selected else None,handoffs=handoffs)
        # The opaque enclosure was subsequently removed at the user's request.
        # Keep the old path as a current-geometry diagnostic, not a requirement
        # to reintroduce wall collisions. The release gate is the new clear path.
        item['old_path_diagnostic_only']=True
        item['passed']=selected is not None and all(h['clear'] for h in handoffs)
        report['passed'] &= item['passed'];report['courses'][theme]=item
    return report

if __name__=='__main__':
    result=inspect()
    (QA/'camera-geometry-results.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))
    sys.exit(0 if result['passed'] else 1)
