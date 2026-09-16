"""Hand-authored Dasher environments, without external assets or executable code.

build_world() returns Roblox XML instances for Workspace/Lobby and
ServerStorage/Maps. COURSE_METADATA exposes the intended traversable routes.
All decorative architecture is non-collidable; only route surfaces collide.
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


def sign(parent, name, text, pos, size, *, bg=None, fg=None, face=2, yaw=0, text_size=42):
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
    scalar(label, 'token', 'Font', 19)
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


def deck(parent, name, x, z, width, depth, top, theme, *, shortcut=False):
    colors = {
        'Skyline': ((217,230,234), (53,77,96), COLORS['cyan']),
        'Neon': ((48,56,79), (21,25,41), (123,177,255)),
        'Grid': ((231,236,240), (81,102,124), (89,220,224)),
    }
    surface, base, accent=colors[theme]
    if shortcut:
        accent=COLORS['gold']
    model=item('Model',name,parent)
    part(model,'Walkable',(x,top-1.1,z),(width,2.2,depth),surface,collide=True,material='concrete' if theme=='Skyline' else 'smooth')
    part(model,'Underside',(x,top-2.5,z),(width-.5,.6,depth-.5),base,material='metal')
    part(model,'LeadingEdge',(x,top+.045,z-depth/2+.19),(width-.5,.09,.22),accent,material='neon')
    part(model,'TrailingEdge',(x,top+.025,z+depth/2-.19),(width-.5,.05,.19),accent,material='neon')
    for side in (-1,1):
        part(model,'InsetRail',(x+side*(width/2-.22),top+.025,z),(.13,.05,max(1,depth-.8)),base)
        part(model,'RimLamp',(x+side*(width/2-.32),top-.73,z-depth/2-.025),(.26,.38,.07),accent,material='neon')
        for off in (-1,1):
            part(model,'CornerFastener',(x+side*(width/2-.65),top+.035,z+off*(depth/2-.7)),(.26,.07,.26),base,material='metal')
    # Two bold forward chevrons; unmistakable direction, no busy arrow decals.
    for dx in (-1,1):
        beam(model,'ForwardMark',(x+dx*.9,top+.075,z+.15),(x,top+.075,z-1.05),.12,accent,'neon')
    if theme=='Neon':
        part(model,'SideConduit',(x,top-1.6,z+depth/2+.035),(width-.8,.12,.08),COLORS['pink'],material='neon')
        for offset in (-1.5,0,1.5):
            if abs(offset)<width/2-1:
                part(model,'Grate',(x+offset,top+.03,z),(0.13,.055,max(1,depth-3)),base)
    if theme=='Grid':
        for xx in (-1,1):
            for zz in (-1,1):
                part(model,'SquareInset',(x+xx*(width/2-1.1),top+.035,z+zz*(depth/2-1.1)),(.7,.07,.7),base)
    return model


def course_route(theme):
    route=[dict(index=0,x=0,z=0,width=26,depth=24,top=22,name='LaunchDeck')]
    patterns={
        'Skyline': [(0,6,0),(-5,3,0),(6,-3,0),(-6,-2,0),(5,-4,0),(-5,4,0),(6,0,0),(-4,3,0)],
        'Neon': [(-4,4,0),(5,-5,0),(-5,3,0),(4,-4,0),(-6,4,0),(5,-2,0),(-4,5,0),(5,-3,0)],
        'Grid': [(0,0,0),(-6,6,0),(6,-6,0),(-5,0,0),(5,-5,0),(-6,5,0),(5,0,0),(-5,5,0)],
    }
    prev=route[0]
    for section in range(8):
        for step in range(3):
            # Long gap requires Dash; the nine-stud destination supplies a
            # usable landing margin without making the launch deck oversized.
            depth=(7,9,14)[step]
            gap=(3,14,2)[step]
            top=(22,23,24)[step]
            if section in (2,5):
                top+=(1,1,0)[step]
            width=(13,10,19)[step]
            if theme=='Grid' and step<2:
                width=depth
            idx=len(route)
            x=patterns[theme][section][step]
            # Two true risk/reward forks: the broad route bends sideways; a
            # narrow middle perch skips one landing while retaining every gate.
            if section in (3,6) and step<2:
                x=13 if section==3 else -13
            p=dict(index=idx,x=x,z=prev['z']-(prev['depth']+depth)/2-gap,
                   width=width,depth=depth,top=top,name=f'Section{section+1:02d}_Pad{step+1}',section=section+1,
                   gate=(section+1 if step==2 else None),gap=gap)
            route.append(p)
            prev=p
    finish=dict(index=25,x=0,z=prev['z']-(prev['depth']+24)/2-5,width=28,depth=24,top=24,name='FinishDeck')
    route.append(finish)
    return route


def arch(parent, name, x, z, top, width, accent, text):
    group=item('Model',name,parent)
    for side in (-1,1):
        part(group,'Pylon',(x+side*width/2,top+6,z),(1.4,12,1.6),COLORS['ink'])
        part(group,'PylonLight',(x+side*(width/2-.16),top+6,z+.83),(.18,10.5,.08),accent,material='neon')
        part(group,'PylonFoot',(x+side*width/2,top+.8,z),(2.6,1.6,2.8),COLORS['navy'])
    sign(group,'Header',text,(x,top+12.3,z),(width+1.5,3,1.4),fg=accent)
    part(group,'HeaderLine',(x,top+10.7,z+.73),(width+1,.16,.08),accent,material='neon')
    return group


def build_course(theme):
    root=item('Model',theme)
    route=course_route(theme)
    platforms=item('Folder','Course',root)
    props=item('Folder','Architecture',root)
    gates=item('Folder','Gates',root)
    hazards=item('Folder','Hazards',root)
    accent={'Skyline':COLORS['cyan'],'Neon':COLORS['pink'],'Grid':COLORS['gold']}[theme]
    for p in route:
        deck(platforms,p['name'],p['x'],p['z'],p['width'],p['depth'],p['top'],theme)
        if p.get('gate'):
            n=p['gate']
            part(gates,f'Gate{n:02d}',(p['x'],p['top']+6,p['z']),(p['width']+3,16,p['depth']+1),accent,transparency=1,touch=True)
            # Stage milestones are route markers, NOT respawn checkpoints.
            sign(props,f'Progress{n:02d}',f'{n:02d} / 08',(p['x']+p['width']/2+2.8,p['top']+2.5,p['z']),(4.8,2.3,.35),fg=accent)
            part(props,'MarkerStand',(p['x']+p['width']/2+2.8,p['top']+.75,p['z']),(.24,2,.24),COLORS['navy'],material='metal')
    shortcuts=[]
    for section,side in ((3,1),(6,-1)):
        prior=route[section*3]
        ending=route[(section+1)*3]
        alt=dict(index=100+section,x=0,z=(prior['z']+ending['z'])/2,
                 width=6,depth=14,top=25,name=f'RiskShortcut{section}',from_index=prior['index'],to_index=ending['index'])
        deck(platforms,alt['name'],alt['x'],alt['z'],alt['width'],alt['depth'],alt['top'],theme,shortcut=True)
        sign(props,'RiskRoute','RISK / REWARD',(alt['x'],alt['top']-1.1,alt['z']+alt['depth']/2+.08),(5.5,1.3,.12),fg=COLORS['gold'])
        shortcuts.append(alt)
    end=route[-1]
    part(root,'Start',(0,26,5),(5,1,5),accent,transparency=1)
    part(root,'Finish',(0,29,end['z']-4),(27,11,7),accent,transparency=1,touch=True)
    arch(props,'StartArch',0,8,22,29,accent,{'Skyline':'CLOUDLINE / 01','Neon':'AFTERHOURS / 02','Grid':'THE GRID / 03'}[theme])
    arch(props,'FinishArch',0,end['z']-4,24,26,COLORS['gold'],'FINISH')
    sign(props,'StartRule','FALL = START AGAIN',(0,25,-6),(17,1.8,.22),fg=COLORS['white'])
    # Start rule sits below eye level; non-collidable and does not conceal the path.
    floorcolor={'Skyline':(137,170,186),'Neon':(14,17,28),'Grid':(45,60,79)}[theme]
    kill=part(hazards,'KillFloor',(0,3,-194),(110,2,488),floorcolor,material='smooth',
              transparency=1 if theme=='Skyline' else 0,touch=True,reflectance=.12 if theme=='Neon' else 0)
    if theme=='Skyline':
        skyline_architecture(props,route)
    elif theme=='Neon':
        neon_architecture(props,route)
    else:
        grid_architecture(props,route)
    COURSE_METADATA[theme]={'primary':route,'shortcuts':shortcuts,
                            'gates':[p['index'] for p in route if p.get('gate')],
                            'finish':(0,29,end['z']-4),'start':(0,26,5),
                            'description':'Only Course/*/Walkable parts collide; all decoration is non-collidable.'}
    return root


def skyline_architecture(parent,route):
    # The central lane stays sunlit; side architecture supplies scale and direction.
    for side in (-1,1):
        for segment in range(9):
            z=10-segment*50
            wall=item('Model',f'SkyWall{side}_{segment}',parent)
            x=side*36
            part(wall,'ConcreteSpine',(x,34,z),(4,35,37),(199,216,224),material='concrete')
            part(wall,'Recess',(x-side*2.03,34,z),(.08,22,29),(61,89,108))
            part(wall,'GlassInset',(x-side*2.10,35,z),(.10,16,24),(144,218,231),material='glass',transparency=.35)
            part(wall,'GoldEdge',(x-side*2.18,24,z),(.12,.25,30),COLORS['gold'],material='neon')
            for rib in (-12,-4,4,12):
                part(wall,'WindowRib',(x-side*2.28,35,z+rib),(.3,19,.4),(167,196,211),material='metal')
            for yy in (27,35,43):
                part(wall,'PanelJoint',(x-side*2.31,yy,z),(.2,.18,30),(115,144,161))
            part(wall,'TowerCap',(x,52,z),(7,1.6,40),(229,238,241))
            part(wall,'VerticalBeacon',(x-side*2.4,35,z+17),(.16,28,.28),COLORS['cyan'],material='neon')
            # Floating service canisters and braces never provide bypass surfaces.
            part(wall,'ServiceCanister',(x-side*3.8,18,z),(2.6,10,3.6),(83,113,128),material='metal')
            beam(wall,'DiagonalBrace',(x-side*1.8,18,z-15),(x-side*6,10,z-4),.55,(109,140,155))
            for yy in (14,18,22):
                part(wall,'CanisterBand',(x-side*3.8,yy,z),(2.9,.28,3.9),(170,195,205),material='metal')
        # Layered distant silhouettes + low clouds, all anchored lightweight parts.
        for distant in range(7):
            z=-45-distant*65
            x=side*(84+(distant%3)*15)
            h=35+(distant*13)%50
            part(parent,'DistantSpire',(x,h/2-17,z),(14,h,24),(125,164,186))
            part(parent,'SpireCrown',(x,h-15,z),(18,1.8,28),(182,204,216))
            for i in range(5):
                part(parent,'Cloud',(side*(39+i*7),-2+(i%3)*1.5,z+(i-2)*7),
                     (28+i*2,10+(i%2)*5,29),(234,243,247),shape=0,transparency=.10)
    for section in range(8):
        z=route[section*3+2]['z']
        # Suspended overhead light frame, high enough to leave jumping space.
        part(parent,'OverheadCrossbeam',(0,56,z),(74,1.4,1.4),(170,196,209),material='metal')
        part(parent,'CrossbeamAccent',(0,55.2,z),(28,.12,.35),COLORS['cyan'],material='neon')
        for side in (-1,1):
            beam(parent,'Suspension',(side*14,56,z),(side*30,67,z),.45,(116,156,178))
    sign(parent,'WorldBillboard','D A S H E R\nSKYLINE TRANSIT',(0,51,-440),(44,10,1),bg=(211,228,235),fg=(39,84,111))


def neon_architecture(parent,route):
    palette=[(31,37,57),(38,37,62),(27,42,58),(45,39,59)]
    for side in (-1,1):
        for building in range(9):
            z=15-building*51
            x=side*36
            h=62+(building%3)*11
            group=item('Model',f'AlleyBuilding{side}_{building}',parent)
            part(group,'Facade',(x,h/2+3,z),(16,h,46),palette[building%4],material='concrete')
            part(group,'FacadeBorder',(x-side*8.1,42,z-21),(.18,74,.35),(57,71,94),material='metal')
            part(group,'RoofLip',(x,h+4,z),(18,2,48),(56,64,89),material='metal')
            for row in range(3):
                yy=23+row*17
                for col in range(3):
                    zz=z-14+col*14
                    tint=(86,111,153) if (row+col+building)%4 else (239,185,124)
                    part(group,'WindowFrame',(x-side*8.07,yy,zz),(.18,6.8,6.2),(14,20,34))
                    part(group,'WindowGlass',(x-side*8.2,yy,zz),(.12,5.8,5.1),tint,material='neon',transparency=.36 if (row+col)%3 else .68)
                    part(group,'WindowMullion',(x-side*8.29,yy,zz),(.12,5.8,.16),(34,44,64))
            # Functional-looking facade furniture gives the alley specificity.
            for ac in range(2):
                zz=z-10+ac*21
                part(group,'AirConditioner',(x-side*9.3,30+ac*15,zz),(2.6,3.8,6),(100,112,130),material='metal')
                for grille in range(5):
                    part(group,'VentGrille',(x-side*10.64,28.9+ac*15+grille*.5,zz),(.10,.16,5.2),(43,52,68))
            for yy in (10,13):
                part(group,'UtilityPipe',(x-side*8.8,yy,z),(.7,.7,45),(79,90,107),material='metal')
            part(group,'Downpipe',(x-side*9,33,z+20),(.8,55,.8),(81,77,101),material='metal')
            if building%2==0:
                accent=COLORS['pink'] if side==1 else COLORS['cyan']
                part(group,'NeonBlade',(side*25,39,z),(1,19,2.8),accent,material='neon')
                sign(group,'NeonSign',['DASH','NIGHT\nSHIFT','VOID','RUN','AFTER\nHOURS'][building//2],(side*23.7,39,z+1.5),
                     (7,15,.25),fg=accent,bg=(24,24,41))
                lamp=part(group,'WallLamp',(side*26,27,z+14),(1,.5,2),accent,material='neon')
                light(lamp,'AlleyGlow',accent,.7,18)
    for line in (-19,19):
        for segment in range(19):
            part(parent,'StreetStripe',(line,4.04,14-segment*24),(.3,.05,13),(85,91,116))
    for cross in range(5):
        z=-48-cross*79
        beam(parent,'HangingCable',(-28,53,z),(0,48,z+3),.15,(8,12,24))
        beam(parent,'HangingCable',(0,48,z+3),(28,53,z),.15,(8,12,24))
        for lantern in range(5):
            x=-18+lantern*9
            part(parent,'CableLantern',(x,48+abs(x)/7,z+3),(1.0,1.8,1),COLORS['gold'],material='neon')
    part(parent,'FarCityTower',(0,67,-466),(72,126,20),(21,28,49))
    sign(parent,'AfterHoursBillboard','AFTER HOURS\nKEEP YOUR MOMENTUM',(0,52,-454),(36,13,1),fg=COLORS['pink'])
    for side in (-1,1):
        part(parent,'TowerBeacon',(side*28,66,-454),(1.1,102,.25),COLORS['cyan'],material='neon')


def grid_architecture(parent,route):
    for side in (-1,1):
        part(parent,'HallWall',(side*34,39,-201),(3,68,466),(213,225,232),material='smooth')
        part(parent,'LowerWall',(side*32.45,13,-201),(.12,15,464),(72,97,118))
        part(parent,'LongAccent',(side*32.3,21.4,-201),(.14,.22,464),COLORS['cyan'],material='neon')
        part(parent,'UpperAccent',(side*32.3,67,-201),(.14,.2,464),COLORS['gold'],material='neon')
        for column in range(23):
            z=20-column*20
            part(parent,'WallJoint',(side*32.4,43,z),(.12,44,.18),(173,192,204))
            for row in range(3):
                yy=29+row*17
                part(parent,'WallSquare',(side*32.3,yy,z-8),(.15,11,11),(199,216,226))
                part(parent,'WallSquareInset',(side*32.18,yy,z-8),(.08,8.5,8.5),(220,234,240))
                if (column+row)%4==0:
                    part(parent,'LitSquare',(side*32.05,yy,z-8),(.09,2.5,2.5),COLORS['cyan'],material='neon')
        for rail in range(9):
            z=11-rail*51
            part(parent,'RoofRail',(side*21,74,z),(23,.7,1.5),(149,177,194),material='metal')
    # Four-wall classic block hall: open ceiling, front/back have high clear sightlines.
    for zz in (33,-435):
        part(parent,'EndWall',(0,39,zz),(71,68,3),(196,214,225))
        for xx in range(-30,31,10):
            part(parent,'EndJoint',(xx,41,zz+(-1.56 if zz>0 else 1.56)),(.15,57,.12),(164,188,204))
    for row in range(22):
        z=20-row*21
        for col in (-2,-1,0,1,2):
            part(parent,'FloorGrid',(col*12,4.03,z),(10,.06,18),(50,69,91) if (row+col)%2 else (55,75,97))
    for side in (-1,1):
        for section in range(8):
            z=route[section*3+3]['z']
            part(parent,'FloatingBlock',(side*27,31+(section%2)*8,z),(5,5,5),COLORS['gold'] if section%3==0 else (88,197,205))
            part(parent,'FloatingBlockInset',(side*27,31+(section%2)*8,z+2.55),(3.3,3.3,.1),(233,245,247))
    sign(parent,'GridTitle','THE GRID\nPRECISION / MOMENTUM',(0,50,-431),(38,10,.4),bg=(33,55,75),fg=COLORS['cyan'])


def build_lobby():
    lobby=item('Model','Lobby')
    base=item('Folder','Structure',lobby)
    detail=item('Folder','Details',lobby)
    part(base,'MainDeck',(0,20,90),(112,4,72),(222,233,237),collide=True,material='concrete')
    part(detail,'Foundation',(0,16.8,90),(108,2.2,68),(50,76,96),material='metal')
    part(detail,'FloorInlay',(0,22.035,90),(51,.07,55),(201,222,228))
    for x in (-27,27):
        part(detail,'FloorAccent',(x,22.08,90),(.19,.06,65),COLORS['cyan'],material='neon')
    for z in (56,124):
        part(detail,'DeckEdge',(0,22.08,z),(108,.1,.3),COLORS['gold'],material='neon')
    for x in (-54,54):
        part(detail,'DeckEdge',(x,22.08,90),(.3,.1,68),COLORS['gold'],material='neon')
    spawn=part(lobby,'SpawnLocation',(0,22.5,85),(7,1,7),(99,209,217),collide=True,cls='SpawnLocation',transparency=1)
    scalar(spawn,'bool','Neutral',True)
    scalar(spawn,'float','Duration',0)
    scalar(spawn,'bool','AllowTeamChangeOnTouch',False)
    # Collision perimeter keeps waiting players on the lobby terrace.
    for x in (-56,56):
        part(base,'SafetyWall',(x,29,90),(1,14,72),(179,216,228),collide=True,material='glass',transparency=.58)
        part(detail,'RailCap',(x,36.1,90),(1.3,.22,72),COLORS['navy'],material='metal')
    for z in (54,126):
        part(base,'SafetyWall',(0,29,z),(112,14,1),(179,216,228),collide=True,material='glass',transparency=.68)
        part(detail,'RailCap',(0,36.1,z),(112,.22,1.3),COLORS['navy'],material='metal')
    arch(detail,'WelcomeArch',0,57,22,35,COLORS['cyan'],'D A S H E R')
    sign(detail,'WelcomeCopy','MASTER THE DASH. OWN THE LINE.',(0,30,55.4),(31,2.3,.3),fg=COLORS['gold'])
    sign(detail,'LobbySubtitle','THREE WORLDS / ONE MOVE',(0,26,55.4),(24,1.5,.3),fg=COLORS['navy'],bg=(216,232,238))
    sign(detail,'RulesPanel','THE RULES\nReach the finish. Falling restarts your run.\nCoins buy style, never speed.',(-35,29,64),(25,10,.6))
    sign(detail,'PracticePanel','WARM-UP JUMPS\nDash activates when the race starts.',(36,29,64),(25,10,.6),fg=COLORS['cyan'])
    # Practice blocks cannot connect to the race lane; the lobby floor catches falls.
    practice=item('Folder','Practice',lobby)
    for i,(x,z,top,w,d) in enumerate([(34,108,24,12,10),(43,91,25.5,10,8),(32,76,26.5,12,9)]):
        deck(practice,f'Practice{i+1}',x,z,w,d,top,'Skyline')
    for i in range(5):
        part(detail,'DirectionDash',(0,22.09,102-i*8),(2.5,.07,2.5),COLORS['cyan'],material='neon',yaw=45)
    # Modern quiet seating / planter furniture, intentional silhouettes.
    for z in (85,109):
        part(base,'BenchSeat',(-40,24,z),(21,1,5),(57,81,100),collide=True)
        for x in (-48,-32):
            part(detail,'BenchLeg',(x,22.9,z),(1.2,2,3),(31,49,67),material='metal')
        part(detail,'BenchLight',(-40,23.65,z+2.52),(17,.15,.07),COLORS['cyan'],material='neon')
    for x,z in [(-49,68),(-49,118),(49,118)]:
        part(detail,'Planter',(x,24,z),(7,4,7),(184,207,215))
        part(detail,'Soil',(x,26.05,z),(6,.1,6),(44,67,72))
        for i in range(5):
            xx=x+math.cos(i*1.25)*1.8
            zz=z+math.sin(i*1.25)*1.8
            part(detail,'Foliage',(xx,28+(i%2)*1.5,zz),(2.9,5+(i%2),2.9),(98,163+i*6,142),shape=0)
    for side in (-1,1):
        for idx in range(6):
            z=62+idx*11
            part(detail,'FacadeStud',(side*55.1,18.5,z),(.5,2.4,4),(117,153,173),material='metal')
        part(detail,'LobbyBeacon',(side*50,39,57),(1.3,10,1.3),COLORS['cyan'],material='neon')
    sign(detail,'BackWordmark','D A S H E R\nWAITING LOUNGE',(0,30,123),(31,9,.45),face=5,fg=COLORS['cyan'])
    # Distant landing supports imply a facility without expensive meshes.
    for x in (-47,47):
        for z in (66,114):
            part(detail,'SupportPier',(x,3,z),(5,28,5),(72,104,125),material='metal')
            part(detail,'PierCollar',(x,12,z),(7,2,7),(145,177,192))
    return lobby


def build_world():
    global _ids
    _ids=itertools.count(1)
    COURSE_METADATA.clear()
    lobby=build_lobby()
    maps=item('Folder','Maps')
    for name in ('Skyline','Neon','Grid'):
        maps.append(build_course(name))
    return lobby,maps


if __name__ == '__main__':
    import json
    lobby,maps=build_world()
    counts={m.find("Properties/string[@name='Name']").text:sum(1 for p in m.iter('Item') if p.get('class')=='Part') for m in maps.findall('Item')}
    print(json.dumps({'parts':counts,'lobby_parts':sum(1 for p in lobby.iter('Item') if p.get('class') in ('Part','SpawnLocation')),
                      'courses':{k:{'finish':v['finish'],'primary_platforms':len(v['primary']),'shortcuts':len(v['shortcuts'])} for k,v in COURSE_METADATA.items()}},indent=2))
