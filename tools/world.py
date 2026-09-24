"""Dasher Ascent: eight obstacle sectors, timed steps and rideable shuttles.

build_world() returns Roblox XML instances for Workspace/Lobby and
ServerStorage/Maps. COURSE_METADATA exposes the intended traversable routes.
Decorative art is non-collidable; route surfaces and the solid hurdle collide.
"""
from __future__ import annotations

import itertools
import math
import xml.etree.ElementTree as ET

COURSE_METADATA = {}
_ids = itertools.count(1)

COLORS = {
    'ink': (22, 32, 49), 'navy': (32, 49, 68), 'white': (233, 240, 244),
    'cyan': (69, 229, 239), 'gold': (255, 201, 91), 'red': (255, 91, 108),
    'muted': (126, 159, 178), 'pink': (232, 107, 242),
}
MATERIALS = {'smooth': 272, 'neon': 288, 'metal': 1088, 'concrete': 816,
             'glass': 1568, 'plastic': 256}


def item(cls, name, parent=None):
    node = ET.Element('Item', {'class': cls, 'referent': f'RBX_DASHER_WORLD_{next(_ids):06d}'})
    props = ET.SubElement(node, 'Properties')
    scalar(node, 'string', 'Name', name)
    if parent is not None:
        parent.append(node)
    return node


def scalar(node, typ, name, value):
    props = node.find('Properties')
    child = ET.SubElement(props, typ, {'name': name})
    child.text = str(value).lower() if isinstance(value, bool) else str(value)
    return child


def vector(node, name, xyz):
    elem = ET.SubElement(node.find('Properties'), 'Vector3', {'name': name})
    for key, val in zip(('X', 'Y', 'Z'), xyz):
        ET.SubElement(elem, key).text = f'{val:.6g}'


def color(node, name, rgb):
    elem = ET.SubElement(node.find('Properties'), 'Color3', {'name': name})
    for key, val in zip(('R', 'G', 'B'), rgb):
        ET.SubElement(elem, key).text = f'{val / 255:.8g}'


def frame(node, pos, yaw=0, roll=0):
    elem = ET.SubElement(node.find('Properties'), 'CoordinateFrame', {'name': 'CFrame'})
    # R_y(yaw) R_z(roll); the route itself stays axis aligned for clean collision.
    a, b = math.radians(yaw), math.radians(roll)
    ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
    vals = (*pos, ca*cb, -ca*sb, sa, sb, cb, 0, -sa*cb, sa*sb, ca)
    for key, val in zip(('X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'), vals):
        ET.SubElement(elem, key).text = f'{val:.9g}'


def part(parent, name, pos, size, rgb, *, collide=False, material='smooth',
         transparency=0, yaw=0, roll=0, shape=1, reflectance=0, cls='Part', touch=False):
    node = item(cls, name, parent)
    frame(node, pos, yaw, roll)
    vector(node, 'size', size)
    r, g, b = rgb
    scalar(node, 'Color3uint8', 'Color3uint8', (255 << 24) | (r << 16) | (g << 8) | b)
    scalar(node, 'bool', 'Anchored', True)
    scalar(node, 'bool', 'CanCollide', collide)
    scalar(node, 'bool', 'CanTouch', touch)
    scalar(node, 'bool', 'CanQuery', collide)
    scalar(node, 'bool', 'CastShadow', material != 'neon' and transparency < .8)
    scalar(node, 'float', 'Transparency', transparency)
    scalar(node, 'float', 'Reflectance', reflectance)
    scalar(node, 'token', 'Material', MATERIALS[material])
    scalar(node, 'token', 'TopSurface', 0)
    scalar(node, 'token', 'BottomSurface', 0)
    if cls == 'Part':
        scalar(node, 'token', 'shape', shape)
    return node


def sign(parent, name, text, pos, size, *, bg=None, fg=None, face=2, yaw=0, text_size=42, title=False):
    p = part(parent, name, pos, size, bg or COLORS['ink'], yaw=yaw)
    gui = item('SurfaceGui', name+'Display', p)
    scalar(gui, 'token', 'Face', face)
    scalar(gui, 'bool', 'AlwaysOnTop', False)
    scalar(gui, 'float', 'LightInfluence', 0)
    scalar(gui, 'float', 'MaxDistance', 210)
    canvas = ET.SubElement(gui.find('Properties'), 'Vector2', {'name': 'CanvasSize'})
    ET.SubElement(canvas, 'X').text = '1000'
    ET.SubElement(canvas, 'Y').text = str(max(100, int(1000*size[1]/max(size[0],1))))
    label = item('TextLabel', name+'Text', gui)
    scalar(label, 'string', 'Text', text)
    scalar(label, 'float', 'BackgroundTransparency', 1)
    color(label, 'TextColor3', fg or COLORS['white'])
    scalar(label, 'float', 'TextSize', text_size)
    scalar(label, 'bool', 'TextScaled', True)
    scalar(label, 'bool', 'TextWrapped', True)
    scalar(label, 'token', 'Font', 26 if title else 35)  # FredokaOne / Nunito
    scalar(label, 'token', 'TextXAlignment', 2)
    scalar(label, 'token', 'TextYAlignment', 1)
    udim = ET.SubElement(label.find('Properties'), 'UDim2', {'name': 'Size'})
    for key,val in [('XS',.91),('XO',0),('YS',.78),('YO',0)]:
        ET.SubElement(udim,key).text=str(val)
    udim = ET.SubElement(label.find('Properties'), 'UDim2', {'name': 'Position'})
    for key,val in [('XS',.045),('XO',0),('YS',.11),('YO',0)]:
        ET.SubElement(udim,key).text=str(val)
    return p


def light(parent, name, rgb, brightness=1.5, radius=22):
    p = item('PointLight', name, parent)
    color(p, 'Color', rgb)
    scalar(p, 'float', 'Brightness', brightness)
    scalar(p, 'float', 'Range', radius)
    scalar(p, 'bool', 'Shadows', False)


def beam(parent, name, a, b, width, rgb, material='metal'):
    # General CFrame basis; cylinder axis is local X, so rods use block geometry.
    delta = [b[i]-a[i] for i in range(3)]
    length = math.sqrt(sum(d*d for d in delta))
    zaxis = [d/length for d in delta]
    up = [0,1,0] if abs(zaxis[1]) < .95 else [1,0,0]
    xaxis = [up[1]*zaxis[2]-up[2]*zaxis[1], up[2]*zaxis[0]-up[0]*zaxis[2], up[0]*zaxis[1]-up[1]*zaxis[0]]
    norm = math.sqrt(sum(d*d for d in xaxis))
    xaxis = [d/norm for d in xaxis]
    yaxis = [zaxis[1]*xaxis[2]-zaxis[2]*xaxis[1], zaxis[2]*xaxis[0]-zaxis[0]*xaxis[2], zaxis[0]*xaxis[1]-zaxis[1]*xaxis[0]]
    node=part(parent,name,tuple((a[i]+b[i])/2 for i in range(3)),(width,width,length),rgb,material=material)
    cf=node.find("Properties/CoordinateFrame[@name='CFrame']")
    for row in range(3):
        for col,axis in enumerate((xaxis,yaxis,zaxis)):
            cf.find(f'R{row}{col}').text=f'{axis[row]:.9g}'
    return node


THEMES={
 'Helix':dict(title='HELIX',base=(47,54,80),accent=(142,181,255),surface=(223,231,249),colors=[(116,148,229),(157,117,227),(86,189,219),(230,164,96),(133,193,143),(212,116,158),(122,168,236),(200,179,237)]),
 'Canopy':dict(title='CANOPY',base=(69,85,66),accent=(183,236,130),surface=(233,228,198),colors=[(145,195,106),(92,180,143),(214,182,104),(147,175,93),(108,193,117),(217,163,109),(108,175,168),(190,206,118)]),
 'Reactor':dict(title='REACTOR',base=(47,58,70),accent=(99,225,236),surface=(218,230,232),colors=[(100,157,204),(95,194,202),(226,149,74),(165,132,208),(199,108,118),(98,180,211),(181,198,99),(160,190,212)]),
}
SECTOR_TYPES=('precision','angle_beams','shuttle','blink','wall_ledge','shuttle','blink','crown_steps')
SECTOR_NAMES=('SPLIT STEPS','CROSSBEAMS','TRANSFER','PHASE SHIFT','SKYLINE','CROSSING','TEMPO','FINAL ASCENT')
GRAVITY, WALK_SPEED, JUMP_SPEED, UPDRAFT_SPEED = 196.2, 20, 52, 88


def value(parent,cls,name,val):
    node=item(cls,name,parent)
    if cls=='Vector3Value':vector(node,'Value',val)
    else:scalar(node,'string' if cls=='StringValue' else ('int' if cls=='IntValue' else 'double'),'Value',val)
    return node


def rotate(x,z,quarter):
    for _ in range(quarter%4):x,z=-z,x
    return x,z


def local_point(p,x,z):
    a=math.radians(p.get('yaw',0));c,s=math.cos(a),math.sin(a)
    dx,dz=x-p['x'],z-p['z']
    return c*dx-s*dz,s*dx+c*dz


def corners(p):
    a=math.radians(p.get('yaw',0));c,s=math.cos(a),math.sin(a)
    return [(p['x']+c*x+s*z,p['z']-s*x+c*z) for x,z in [(-p['width']/2,-p['depth']/2),(p['width']/2,-p['depth']/2),(p['width']/2,p['depth']/2),(-p['width']/2,p['depth']/2)]]


def point_segment_distance(p,a,b):
    dx,dz=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)


def inside(p,x,z,padding=0):
    lx,lz=local_point(p,x,z)
    return abs(lx)<p['width']/2+padding and abs(lz)<p['depth']/2+padding


def rectangle_gap(a,b):
    ac,bc=corners(a),corners(b)
    separated=False
    for p in (a,b):
        yaw=math.radians(p.get('yaw',0))
        for axis in ((math.cos(yaw),-math.sin(yaw)),(math.sin(yaw),math.cos(yaw))):
            av=[x*axis[0]+z*axis[1] for x,z in ac];bv=[x*axis[0]+z*axis[1] for x,z in bc]
            if max(av)<min(bv) or max(bv)<min(av):separated=True
    if not separated:return 0
    return min(point_segment_distance(v,edge[i],edge[(i+1)%4]) for points,edge in ((ac,bc),(bc,ac)) for v in points for i in range(4))


def motion_positions(p):
    if p.get('motion')!='Shuttle':return [p]
    tx,ty,tz=p['travel']
    return [dict(p,x=p['x']+tx*f,z=p['z']+tz*f,top=p['top']+ty*f) for f in (0,.25,.5,.75,1)]


def clear_headroom(route):
    # Centre and departure lane must never be under the next sector. A normal
    # R15 avatar needs >6.2 studs; lift launch needs the full ballistic apex.
    for standing in route:
        limit=25.7 if standing['kind']=='updraft_launch' else 6.2
        for s in motion_positions(standing):
            for upper in route:
                if standing['name']==upper['name']:continue
                for u in motion_positions(upper):
                    clearance=u['top']-1.25-s['top']
                    if 0<clearance<limit and inside(u,s['x'],s['z'],1.1):return False
    return True


def transition_metrics(previous,target):
    # Exit from the far dock, board at the near dock. All distances use actual
    # rectangle edges, not just centre distance (important on narrow beams).
    previous=motion_positions(previous)[-1]
    rise=target['top']-previous['top'];gap=rectangle_gap(previous,target)
    speed=UPDRAFT_SPEED if target['updraft'] else JUMP_SPEED
    disc=speed*speed-2*GRAVITY*rise
    flight=(speed+math.sqrt(disc))/GRAVITY if disc>=0 else 0
    return dict(from_name=previous['name'],to_name=target['name'],rise=rise,gap=gap,
                flight=flight,range=WALK_SPEED*flight,landing_margin=WALK_SPEED*flight-gap,
                updraft=target['updraft'])


def approach_points(previous,target,inset=.5,obstacles=None):
    """Return edge takeoff/landing hints, inset into both real support faces.

    These are advisory metadata for native QA, not runtime teleport targets.
    Taking every jump from slab centre would incorrectly reject these deliberate
    running jumps. The returned horizontal distance must fit the actual parabola.
    """
    authored_previous=previous
    previous=motion_positions(previous)[-1]
    # Beam kill rails occupy the side margins. Plan the jump through the safe
    # centre lane, not through a physically solid but lethal slab corner.
    if previous.get('index') in (10,38):previous=dict(previous,depth=previous['depth']-2.4)
    if target.get('index') in (10,38):target=dict(target,depth=target['depth']-2.4)
    ac,bc=corners(previous),corners(target)
    candidates=[]
    for reverse,(pts,edges) in enumerate(((ac,bc),(bc,ac))):
        for p in pts:
            for i,a in enumerate(edges):
                b=edges[(i+1)%4];dx,dz=b[0]-a[0],b[1]-a[1]
                t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
                q=(a[0]+t*dx,a[1]+t*dz)
                candidates.append((math.dist(p,q),q,p) if reverse else (math.dist(p,q),p,q))
    _,a,b=min(candidates)
    def pull_in(point,p):
        dx,dz=p['x']-point[0],p['z']-point[1];length=math.hypot(dx,dz)
        return (point[0]+dx/max(length,1)*inset,point[1]+dz/max(length,1)*inset)
    a,b=pull_in(a,previous),pull_in(b,target)
    hint=dict(takeoff=(a[0],previous['top'],a[1]),landing=(b[0],target['top'],b[1]),distance=math.dist(a,b))
    return clear_jump_approach(authored_previous,target,hint,obstacles) if obstacles is not None else hint


def capsule_hits_surface(p,x,feet,z):
    """Conservative upright R15 capsule against an oriented 1.25-stud slab."""
    radius,height=1.0,5.5
    lx,lz=local_point(p,x,z)
    dx=max(0,abs(lx)-p['width']/2);dz=max(0,abs(lz)-p['depth']/2)
    low,high=feet+radius,feet+height-radius
    dy=max(0,p['top']-1.25-high,low-p['top'])
    return dx*dx+dz*dz+dy*dy<radius*radius-.001


def jump_corridor(previous,target,takeoff,landing,obstacles):
    """Check ground approach, 120Hz ballistic capsule, and landing exit.

    Updraft first clears the receiver height vertically, as a human can do with
    Q before moving toward it. The returned delay makes this requirement visible
    to QA instead of silently assuming a horizontally instantaneous takeoff.
    """
    speed=UPDRAFT_SPEED if target['updraft'] else JUMP_SPEED
    rise=target['top']-previous['top'];disc=speed*speed-2*GRAVITY*rise
    flight=(speed+math.sqrt(disc))/GRAVITY
    delay=(speed-math.sqrt(speed*speed-2*GRAVITY*(rise+.5)))/GRAVITY if target['updraft'] else 0
    distance=math.dist(takeoff,landing)
    if distance>WALK_SPEED*(flight-delay)-.05:return False,'horizontal_range',delay
    for a,b,y in (((previous['x'],previous['z']),takeoff,previous['top']),
                  (landing,(target['x'],target['z']),target['top'])):
        for step in range(17):
            f=step/16;x=a[0]+(b[0]-a[0])*f;z=a[1]+(b[1]-a[1])*f
            for slab in obstacles:
                if slab['name'] not in (previous['name'],target['name']) and capsule_hits_surface(slab,x,y,z):
                    return False,'ground_overhang:'+slab['name'],delay
    steps=math.ceil(flight*120)
    for step in range(1,steps):
        time=flight*step/steps;f=min(1,max(0,time-delay)*WALK_SPEED/max(distance,.01))
        x=takeoff[0]+(landing[0]-takeoff[0])*f;z=takeoff[1]+(landing[1]-takeoff[1])*f
        feet=previous['top']+speed*time-GRAVITY*time*time/2
        for slab in obstacles:
            if capsule_hits_surface(slab,x,feet,z):return False,'jump_obstruction:'+slab['name'],delay
    return True,'clear',delay


def approach_grid(p):
    width,depth=p['width'],p['depth']
    if p.get('index') in (10,38):depth-=2.4
    halfx,halfz=max(.1,width/2-.5),max(.1,depth/2-.5)
    angle=math.radians(p.get('yaw',0));c,s=math.cos(angle),math.sin(angle)
    return [(p['x']+c*x*halfx+s*z*halfz,p['z']-s*x*halfx+c*z*halfz)
            for x in (-1,-.66,-.33,0,.33,.66,1) for z in (-1,-.66,-.33,0,.33,.66,1)]


def clear_jump_approach(authored_previous,target,hint,all_surfaces):
    previous=motion_positions(authored_previous)[-1]
    speed=UPDRAFT_SPEED if target['updraft'] else JUMP_SPEED
    max_top=previous['top']+speed*speed/(2*GRAVITY)+5.5
    # Use the actual far/near dock for this pair, not every duplicate phase of
    # the same moving slab. Other movers are swept across their full travel.
    slabs=[previous,target]+[p for other in all_surfaces if other['name'] not in (previous['name'],target['name'])
                              for p in motion_positions(other) if previous['top']-1<p['top']<max_top+1.25]
    a=(hint['takeoff'][0],hint['takeoff'][2]);b=(hint['landing'][0],hint['landing'][2])
    clear,reason,delay=jump_corridor(previous,target,a,b,slabs)
    if clear:return dict(hint,corridor_checked=True,horizontal_delay=delay,corridor_adjusted=False)
    rise=target['top']-previous['top']
    flight=(speed+math.sqrt(speed*speed-2*GRAVITY*rise))/GRAVITY
    max_range=WALK_SPEED*(flight-delay)-.05
    candidates=sorted((math.dist(a,b),a,b) for a in approach_grid(previous) for b in approach_grid(target) if math.dist(a,b)<max_range)
    for distance,a,b in candidates:
        clear,_,delay=jump_corridor(previous,target,a,b,slabs)
        if clear:
            return dict(takeoff=(a[0],previous['top'],a[1]),landing=(b[0],target['top'],b[1]),distance=distance,
                        corridor_checked=True,horizontal_delay=delay,corridor_adjusted=True,original_obstruction=reason)
    raise AssertionError(('No clear avatar jump corridor',previous['name'],target['name'],reason))


def transitions_valid(route):
    for previous,target in zip(route,route[1:]):
        m=transition_metrics(previous,target)
        if target['updraft']:
            if not 12<=m['rise']<=15 or m['gap']>8:return False
        else:
            if not -1<=m['rise']<=3.5 or m['gap']>8.60001:return False
        if m['landing_margin']<1.1:return False
        if inside(target,previous['x'],previous['z'],.8):return False
    return True


def template(theme,kind):
    if kind=='shuttle':
        return [(0,16),(0,29),(31,29),(45,29),(43,14),(30,8),(17,3),(0,0)],[(11,9),(22,17)],[]
    if theme=='Canopy':
        return [(12,14),(25,17),(32,5),(45,3),(42,-12),(29,-19),(16,-11),(0,0)],[(15,-2),(27,-8)],[(33,16),(20,20),(8,13)]
    if theme=='Reactor':
        return [(0,16),(13,22),(26,22),(42,22),(44,7),(30,5),(17,0),(0,0)],[(13,1),(25,8)],[(29,34),(17,25),(7,14)]
    return [(0,16),(12,24),(24,16),(40,16),(43,1),(31,-6),(18,-7),(0,0)],[(15,-4),(27,3)],[(28,27),(16,22),(5,14)]


def authored_sector(theme,sector,quarter):
    kind=SECTOR_TYPES[sector-1]
    points,pre,post=template(theme,kind)
    if theme=='Canopy' and sector==1:points[0]=(15,19)
    base=22+(sector-1)*26
    heights=(1.5,3.5,5,19,20.5,22,24,26)
    route=[];alts=[]
    for step,((px,pz),height) in enumerate(zip(points,heights),1):
        x,z=rotate(px,pz,quarter)
        w=d=5.5 if step==1 else 5
        padkind='precision'
        if step in (6,7):w=d=6
        if kind=='angle_beams' and step in (2,6):w,d,padkind=7,3.2,'balance'
        if kind=='wall_ledge' and step in (1,5):w,d,padkind=4,10,'wall_ledge'
        if kind=='wall_ledge' and theme=='Reactor' and step==5:w=5
        if kind=='crown_steps' and step in (1,2,5):w=d=4.8
        if step==3:w=d=10;padkind='updraft_launch'
        if step==4:w=d=10;padkind='updraft_receiver'
        if step==8:w=d=14;padkind='sector_rest'
        if kind=='shuttle' and step==2:w=d=6;padkind='shuttle'
        if kind=='blink' and step in (5,6):padkind='blink'
        p=dict(name=f'P{(sector-1)*8+step:03d}',index=(sector-1)*8+step,x=x,z=z,top=base+height,width=w,depth=d,
               yaw=-quarter*90,section=sector,completed_stage=sector if step==8 else sector-1,
               updraft=step==4,kind=padkind,sector_type=kind,branch='main')
        if padkind=='shuttle':
            tx,tz=rotate(18,0,quarter);p.update(motion='Shuttle',travel=(tx,0,tz),period=8,dwell=1.2,phase=0)
        if padkind=='blink':p.update(motion='Blink',period=6.6,on_duration=4.8,warning_duration=1.1,phase=0 if step==5 else .65)
        route.append(p)
    for position,xy in enumerate(pre+post,1):
        before=position<=len(pre);step=position if before else position-len(pre)
        height=(1.5,3.5)[step-1] if before else (20.5,22.5,24)[step-1]
        x,z=rotate(*xy,quarter)
        w=5 if kind=='shuttle' or (theme=='Reactor' and not before) else 4.5
        # A genuinely narrower, shorter route; it is not a duplicate arrow on
        # the same slabs. In timed sectors the alternate remains static.
        p=dict(name=f'B{sector:02d}_{position:02d}',index=200+sector*10+position,x=x,z=z,top=base+height,width=w,depth=w,
               yaw=-quarter*90,section=sector,completed_stage=sector-1,updraft=False,kind='shortcut',sector_type=kind,
               branch='alternate',branch_phase='before_lift' if before else 'after_lift')
        alts.append(p)
    return route,alts


def branch_chains(previous,main,alts):
    pre=[p for p in alts if p['branch_phase']=='before_lift']
    post=[p for p in alts if p['branch_phase']=='after_lift']
    return [[previous]+pre+[main[2]], *([[main[3]]+post+[main[7]]] if post else [])]


def course_routes(theme):
    launch=dict(name='LaunchDeck',index=0,x=0,z=0,top=22,width=24,depth=18,yaw=0,section=0,completed_stage=0,updraft=False,kind='launch',branch='shared')
    preferences={'Helix':(0,1,2,3,0,0,2,3),'Canopy':(1,2,3,0,1,2,3,0),'Reactor':(2,3,0,1,2,3,0,1)}[theme]
    def choose(sector,route,alternates,branch_data):
        if sector==9:
            for cx,cz in ((0,-21),(-21,0),(0,21),(21,0)):
                crown=dict(name='CrownDeck',index=65,x=cx,z=cz,top=232,width=24,depth=20,yaw=0,section=8,completed_stage=8,updraft=False,kind='crown',branch='shared')
                if transitions_valid([route[-1],crown]) and clear_headroom(route[-8:]+alternates[-5:]+[crown]):
                    return route+[crown],alternates,branch_data
            return None
        pref=preferences[sector-1]
        for q in [pref]+[n for n in range(4) if n!=pref]:
            main,alts=authored_sector(theme,sector,q)
            chains=branch_chains(route[-1],main,alts)
            if not transitions_valid([route[-1]]+main) or not all(transitions_valid(chain) for chain in chains):continue
            recent=[p for p in route+alternates if p['top']>=main[0]['top']-32]
            if not clear_headroom(recent+main+alts):continue
            desc=dict(section=sector,title=SECTOR_NAMES[sector-1],type=SECTOR_TYPES[sector-1],quarter=q,
                      main=[p['name'] for p in [route[-1]]+main],
                      alternatives=[dict(label='Precision bypass' if n==0 else 'Outer shortcut',
                                         chain=[p['name'] for p in chain],
                                         bypasses=[p['name'] for p in (main[:2] if n==0 else main[4:7])]) for n,chain in enumerate(chains)])
            result=choose(sector+1,route+main,alternates+alts,branch_data+[desc])
            if result:return result
        return None
    result=choose(1,[launch],[],[])
    assert result,f'No feasible authored arrangement for {theme}'
    return result


def course_route(theme):
    return course_routes(theme)[0]


def recovery_ledges(route,alternates):
    results=[]
    for section in range(1,9):
        receiver=route[(section-1)*8+4]
        options=[]
        for axis in ('x','z'):
            for side in (-1,1):
                p=dict(name=f'Catch{section:02d}',index=100+section,x=receiver['x'],z=receiver['z'],top=receiver['top']-2,
                       width=9,depth=8,yaw=0,section=section,completed_stage=section-1,updraft=False,kind='catch',rejoin=receiver['name'])
                p[axis]+=side*((10+p['width' if axis=='x' else 'depth'])/2+4.5)
                if clear_headroom(route+alternates+results+[p]) and transitions_valid([p,dict(receiver,updraft=False)]):options.append(p)
        assert options,('No clear physical fall recovery',section)
        results.append(min(options,key=lambda p:abs(p['x'])+abs(p['z'])))
    return results


def platform(parent,p,theme,*,catch=False):
    t=THEMES[theme];model=item('Model',p['name'],parent)
    x,z,y,w,d,yaw=p['x'],p['z'],p['top'],p['width'],p['depth'],p.get('yaw',0)
    tone=t['colors'][max(0,p['section']-1)]
    if p['kind'] in ('launch','sector_rest','crown'):tone=t['surface']
    if p['kind']=='shortcut':tone=tuple(min(255,int(c*.78+42)) for c in tone)
    if catch:tone=tuple(int(c*.65+255*.35) for c in tone)
    walkable=part(model,'Walkable',(x,y-.625,z),(w,1.25,d),tone,collide=True,yaw=yaw)
    value(walkable,'IntValue','CompletedStage',p['completed_stage'])
    part(model,'Underside',(x,y-1.42,z),(max(.5,w-.35),.35,max(.5,d-.35)),t['base'],yaw=yaw)
    if p['kind']=='shortcut':
        part(model,'RiskStripe',(x,y+.025,z),(min(1.2,w-1),.05,min(1.2,d-1)),(255,227,144),yaw=45-quarter_yaw(p))
    if p['kind'] in ('updraft_launch','updraft_receiver'):
        part(model,'UpdraftInset',(x,y+.035,z),(3,.07,3),t['accent'],yaw=45)
        for side in (-1,1):beam(model,'UpChevron',(x+side*.7,y+.12,z+.55),(x,y+.12,z-.5),.12,t['base'],'smooth')
    if p['kind'] in ('sector_rest','crown'):
        sign(model,'SectorNumber',f'{p["section"]:02d}',(x,y-.52,z+d/2+.04),(3,.9,.06),bg=t['base'],fg=(239,243,241))
        for side in (-1,1):part(model,'RestStripe',(x+side*(w/2-.35),y+.025,z),(.12,.05,d-1),t['accent'])
    if p.get('motion'):
        value(model,'StringValue','Motion',p['motion']);value(model,'NumberValue','Period',p['period']);value(model,'NumberValue','Phase',p['phase'])
        if p['motion']=='Shuttle':
            value(model,'Vector3Value','Travel',p['travel']);value(model,'NumberValue','Dwell',p['dwell'])
            part(model,'RideInset',(x,y+.04,z),(w-1,.08,d-1),(94,221,249),yaw=yaw)
            part(model,'RideCentre',(x,y+.09,z),(1.8,.04,1.8),(227,249,255),yaw=yaw)
        else:
            value(model,'NumberValue','OnDuration',p['on_duration']);value(model,'NumberValue','WarningDuration',p['warning_duration'])
            part(model,'StateIndicator',(x,y+.045,z),(w-.6,.09,.35),(248,226,119),yaw=yaw,material='neon')
    return model


def quarter_yaw(p):return p.get('yaw',0)


def circle_ring(parent,name,center,radius,width,color,*,segments=24,material='smooth',start=0,end=math.tau):
    x,y,z=center
    for n in range(segments):
        a=start+(end-start)*n/segments;b=start+(end-start)*(n+1)/segments
        beam(parent,name,(x+math.cos(a)*radius,y,z+math.sin(a)*radius),(x+math.cos(b)*radius,y,z+math.sin(b)*radius),width,color,material)


def add_obstacles(props,hazards,route,alternates,theme):
    t=THEMES[theme];records=[]
    # Real danger beside two thin beams, never fake red decorative collision.
    for index in (10,38):
        p=route[index]
        angle=math.radians(p.get('yaw',0));c,s=math.cos(angle),math.sin(angle)
        for side in (-1,1):
            off=(0,side*(p['depth']/2+.3));size=(p['width'],.45,.25)
            pos=(p['x']+c*off[0]+s*off[1],p['top']+.7,p['z']-s*off[0]+c*off[1])
            part(hazards,f'Edge{index}_{side}',pos,size,(250,106,97),material='neon',touch=True,yaw=p.get('yaw',0))
            records.append(dict(name=f'Edge{index}_{side}',kind='kill_edge',platform=p['name'],position=pos,size=size))
    # Optional shortcuts feature sweeping arms: take the outer static chain or
    # time a jump through the inner half. Main chains remain unambiguous.
    for section in (2,7):
        p=next(p for p in alternates if p['section']==section and p['branch_phase']=='before_lift')
        # Sweep only the outside half; a 2-stud safe centre lane is retained.
        options=[]
        for a in range(16):
            angle=a*math.tau/16;x,z=p['x']+9*math.cos(angle),p['z']+9*math.sin(angle)
            distance=min((rectangle_gap(dict(x=x,z=z,width=1,depth=1,yaw=0),q) for q in route if abs(q['top']-p['top'])<7),default=50)
            options.append((distance,x,z))
        distance,x,z=max(options)
        center=(x,p['top']+1.1,z)
        spinner=item('Model',f'Spinner{section:02d}',hazards)
        value(spinner,'StringValue','Motion','Spinner');value(spinner,'NumberValue','AngularSpeed',.8);value(spinner,'NumberValue','Phase',section*.4)
        part(spinner,'Center',center,(.3,.3,.3),t['base'],transparency=1)
        part(spinner,'Bar',center,(16,.5,.6),(255,137,89),touch=True,material='neon')
        part(props,'SpinnerPivot',(x,p['top']-.1,z),(1.2,1.2,1.2),t['base'],shape=0)
        records.append(dict(name=f'Spinner{section:02d}',kind='spinner',center=center,size=(16,.5,.6),angular_speed=.8,section=section,main_clearance=distance))
    return records


def architecture(parent,route,theme):
    t=THEMES[theme]
    if theme=='Helix':
        for n,y in enumerate((21,73,125,177,239)):
            circle_ring(parent,'OrbitalFrame',(0,y,0),58,.7,(123,145,190),segments=16,start=.4+n*.5,end=4.0+n*.5)
            for side in (-1,1):part(parent,'Satellite',(side*57,y+3,0),(3,5,3),t['accent'],material='glass',transparency=.3,yaw=35)
        for x,z in ((-57,-31),(57,31)):part(parent,'OuterPier',(x,129,z),(1.8,232,1.8),(117,140,184))
    elif theme=='Canopy':
        for x,z in ((53,48),(-55,-46),(52,-50)):
            part(parent,'LivingTrunk',(x,120,z),(4.5,228,4.5),(111,89,62))
            for y in (37,89,141,193,239):
                beam(parent,'Branch',(x,y,z),(x*.78,y+7,z*.78),1.8,(129,110,73),'smooth')
                part(parent,'LeafCanopy',(x,y+9,z),(18,6,20),(112,160,91),shape=0)
                for offset in (-4,4):beam(parent,'HangingVine',(x+offset,y+6,z),(x+offset,y-8,z),.22,(134,172,83),'smooth')
        for p in route:
            if p['kind'] in ('sector_rest','updraft_launch'):
                for side in (-1,1):part(parent,'WoodSupport',(p['x']+side*3,p['top']-2.3,p['z']),(1.1,3,1.1),(134,106,73))
    else:
        for x,z in ((57,40),(-57,-40),(-57,40)):
            part(parent,'CoolingSpine',(x,122,z),(3.5,232,3.5),(83,113,131),material='metal')
            for y in (22,74,126,178,238):
                part(parent,'SpineClamp',(x,y,z),(6.5,1.2,6.5),t['base'],material='metal')
                part(parent,'StatusLamp',(x,y+2,z),(3.6,.35,3.6),t['accent'],material='neon')
        for y in (22,126,238):circle_ring(parent,'ReactorFrame',(0,y,0),61,.5,t['base'],segments=12,material='metal')
    for p in route:
        if p['kind']=='wall_ledge':
            a=math.radians(p.get('yaw',0));off=p['width']/2+1.7
            part(parent,'LedgeWall',(p['x']+math.cos(a)*off,p['top']+2.7,p['z']-math.sin(a)*off),
                 (.8,7,p['depth']+2),t['base'],yaw=p.get('yaw',0))


def build_course(theme):
    root=item('Model',theme);t=THEMES[theme]
    course=item('Folder','Course',root);catches=item('Folder','CatchLedges',root)
    props=item('Folder','Architecture',root);gates=item('Folder','Gates',root);hazards=item('Folder','Hazards',root)
    route,alternates,branches=course_routes(theme);recovery=recovery_ledges(route,alternates)
    for p in route+alternates:
        platform(course,p,theme)
        if p['kind']=='sector_rest':
            gate=part(gates,f'Gate{p["section"]:02d}',(p['x'],p['top']+2,p['z']),(14,6,14),t['accent'],transparency=1,touch=True)
            value(gate,'StringValue','Landing',p['name'])
        if p.get('motion')=='Shuttle':
            tx,ty,tz=p['travel'];a=(p['x'],p['top']-2.5,p['z']);b=(a[0]+tx,a[1]+ty,a[2]+tz)
            beam(props,'ShuttleRail',a,b,.2,t['base'],'metal')
            for point in (a,b):part(props,'DockStop',point,(1.4,.8,1.4),t['accent'])
        if p['kind']=='updraft_launch':
            receiver=route[p['index']+1]
            dx,dz=receiver['x']-p['x'],receiver['z']-p['z'];length=math.hypot(dx,dz)
            x,z=p['x']-dz/length*7,p['z']+dx/length*7
            for n in range(3):
                yy=p['top']+3+n*3
                for wing in (-1,1):beam(props,'LiftGuide',(x+wing*.65,yy-.6,z),(x,yy,z),.15,t['accent'],'neon')
    for p in recovery:platform(catches,p,theme,catch=True)
    obstacles=add_obstacles(props,hazards,route,alternates,theme)
    first=route[1];yaw=math.degrees(math.atan2(-first['x'],-first['z']))
    crown=route[-1];finish=(crown['x'],crown['top']+5,crown['z'])
    part(root,'Start',(0,26,0),(4,1,4),t['accent'],transparency=1,yaw=yaw)
    for i,(x,z) in enumerate(( (x,z) for z in (-4,4) for x in (-8,-4,0,4,8)),1):
        part(root,f'Start{i:02d}',(x,26,z),(1,1,1),t['accent'],transparency=1,yaw=yaw)
        part(props,'StartMark',(x,22.025,z),(.8,.05,.8),t['base'],yaw=45)
    part(root,'Finish',finish,(24,12,20),t['accent'],transparency=1,touch=True)
    part(root,'Bounds',(0,131,0),(152,286,152),t['accent'],transparency=1)
    part(hazards,'KillFloor',(0,-12,0),(152,2,152),(167,193,207),transparency=1,touch=True)
    architecture(props,route,theme)
    # An unmistakable finish plaza. Trigger covers the whole crown so touching
    # a hidden point is never required; the visible arch is only presentation.
    for x in (-12.6,12.6):part(props,'FinishPost',(crown['x']+x,237,crown['z']+8),(.8,10,.8),t['base'])
    part(props,'FinishLintel',(crown['x'],242,crown['z']+8),(26,.8,1),t['accent'])
    sign(props,'FinishWord','FINISH',(crown['x'],242,crown['z']+8.6),(16,2.4,.15),bg=t['base'],fg=t['surface'],title=True)
    for xx in range(-5,6):
        part(props,'FinishCheck',(crown['x']+xx*2,232.045,crown['z']),(1.95,.09,2),t['base'] if xx%2 else t['surface'])
    by_name={p['name']:p for p in route+alternates}
    edges=[transition_metrics(a,b) for a,b in zip(route,route[1:])]
    all_surfaces=route+alternates+recovery
    for edge,a,b in zip(edges,route,route[1:]):edge.update(approach_points(a,b,obstacles=all_surfaces))
    for section in branches:
        for alternative in section['alternatives']:
            chain=[by_name[name] for name in alternative['chain']]
            alternative['transitions']=[dict(transition_metrics(a,b),**approach_points(a,b,obstacles=all_surfaces)) for a,b in zip(chain,chain[1:])]
    COURSE_METADATA[theme]=dict(primary=route,route=route,alternates=alternates,branches=branches,catch_ledges=recovery,obstacles=obstacles,
        gates=[dict(name=f'Gate{p["section"]:02d}',height=p['top']+2,center=(p['x'],p['top']+2,p['z']),size=(14,6,14),landing=p['name']) for p in route if p['kind']=='sector_rest'],
        start=(0,26,0),finish=finish,finish_surface=232,course_height_studs=210,
        required_updrafts=[p['name'] for p in route if p['updraft']],
        movers=[p for p in route if p.get('motion')=='Shuttle'],timed_platforms=[p for p in route if p.get('motion')=='Blink'],
        transitions=edges,bounds=dict(center=(0,131,0),size=(152,286,152)),
        difficulty=dict(normal_gap_min=round(min(p['gap'] for p in edges if not p['updraft']),3),normal_gap_max=round(max(p['gap'] for p in edges if not p['updraft']),3),
                        mandatory_lift_rise=14,alternate_routes=sum(len(b['alternatives']) for b in branches),physics=dict(gravity=GRAVITY,walk_speed=WALK_SPEED,jump_speed=JUMP_SPEED,updraft_speed=UPDRAFT_SPEED)),
        description='Eight demanding tower sectors with independent precision bypasses, route choice, 14-stud Updraft climbs, moving shuttles, timed steps and recoverable falls.')
    return root


def build_lobby():
    from lobby05 import build_lobby as make_lobby
    return make_lobby()


def build_world():
    global _ids
    _ids=itertools.count(1);COURSE_METADATA.clear();lobby=build_lobby();maps=item('Folder','Maps')
    for theme in THEMES:maps.append(build_course(theme))
    return lobby,maps


def verify_geometry():
    lobby,maps=build_world();counts={}
    for theme,data in COURSE_METADATA.items():
        route,alts=data['route'],data['alternates'];by_name={p['name']:p for p in route+alts}
        assert len(route)==66 and len(data['required_updrafts'])==8
        assert len(data['branches'])==8 and len(alts)==34
        assert [g['landing'] for g in data['gates']]==[f'P{n:03d}' for n in range(8,65,8)]
        assert transitions_valid(route),(theme,'primary reachability')
        assert clear_headroom(route+alts+data['catch_ledges']),(theme,'headroom')
        assert data['difficulty']['normal_gap_min']>=3.5,(theme,'trivial near-touching main gap')
        assert len(data['movers'])==2 and len(data['timed_platforms'])==4
        for branch in data['branches']:
            assert branch['alternatives'],(theme,branch['section'],'no genuine choice')
            for alternative in branch['alternatives']:
                chain=[by_name[name] for name in alternative['chain']]
                assert transitions_valid(chain),(theme,alternative)
                assert any(name not in branch['main'] for name in alternative['chain'])
                assert all(p['landing_margin']>=1.1 for p in alternative['transitions'])
                assert all(p['distance']<p['range'] for p in alternative['transitions']), (theme,'alternate edge approach range')
                assert all(p['corridor_checked'] for p in alternative['transitions']), (theme,'alternate jump corridor')
        assert all(p['distance']<p['range'] for p in data['transitions']), (theme,'main edge approach range')
        assert all(p['corridor_checked'] for p in data['transitions']), (theme,'main jump corridor')
        assert all(p['rise']==14 for p in data['transitions'] if p['updraft'])
        for obstacle in data['obstacles']:
            if obstacle['kind']=='spinner':assert obstacle['main_clearance']>10,(theme,'spinner clips main route')
        for p in data['movers']:
            previous,target=route[p['index']-1],route[p['index']+1]
            assert rectangle_gap(previous,p)<=8.6 and rectangle_gap(motion_positions(p)[-1],target)<=8.6
            assert rectangle_gap(p,target)>18,'A real ride must be needed before the main-route exit'
            assert math.sqrt(sum(x*x for x in p['travel']))==18
        for p in data['catch_ledges']:
            receiver=next(q for q in route if q['name']==p['rejoin'])
            assert 4<=rectangle_gap(p,receiver)<=5 and p['top']==receiver['top']-2
        for p in route+alts+data['catch_ledges']:
            for x,z in corners(p):assert abs(x)<75 and abs(z)<75,(theme,p['name'],x,z)
            assert 0<=p['completed_stage']<=8
        model=next(m for m in maps.findall('Item') if m.find("Properties/string[@name='Name']").text==theme)
        counts[theme]=sum(1 for n in model.iter('Item') if n.attrib['class']=='Part')
        assert counts[theme]<1000
        assert not any(n.attrib['class'] in ('Script','LocalScript','ModuleScript') for n in model.iter('Item'))
    refs=[n.attrib['referent'] for root in (lobby,maps) for n in root.iter('Item')]
    assert len(refs)==len(set(refs))
    return counts,sum(1 for n in lobby.iter('Item') if n.attrib['class'] in ('Part','SpawnLocation'))


if __name__=='__main__':
    import json,sys
    # lobby05 lazily imports these helpers. A direct script run must still share
    # the same referent counter as that import, rather than loading world twice.
    sys.modules['world']=sys.modules[__name__]
    counts,lobby_count=verify_geometry()
    print(json.dumps(dict(parts=counts,lobby_parts=lobby_count,courses={name:dict(route_count=len(m['route']),alternate_platforms=len(m['alternates']),height=m['course_height_studs'],difficulty=m['difficulty']) for name,m in COURSE_METADATA.items()}),indent=2))
