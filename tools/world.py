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
    # BuilderSansBold is official Enum.Font value 48, avoiding deprecated aliases.
    scalar(label, 'token', 'Font', 48)
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


THEMES = {
    'Skyline': dict(title='CLOUDLINE', number='01', surface=(219, 229, 234), base=(70, 91, 109), accent=(99, 222, 231), floor=(148, 182, 201)),
    'Neon': dict(title='AFTERHOURS', number='02', surface=(53, 60, 81), base=(24, 28, 44), accent=(183, 137, 250), floor=(14, 19, 32)),
    'Grid': dict(title='THE GRID', number='03', surface=(225, 233, 236), base=(78, 101, 117), accent=(104, 223, 207), floor=(35, 47, 65)),
    'Foundry': dict(title='FOUNDRY', number='04', surface=(84, 86, 89), base=(36, 40, 49), accent=(255, 186, 92), floor=(38, 31, 26)),
    'Zenith': dict(title='ZENITH', number='05', surface=(173, 189, 212), base=(36, 49, 75), accent=(167, 186, 255), floor=(18, 26, 46)),
}


def deck(parent, name, x, z, width, depth, top, theme, *, shortcut=False):
    """A compact kit: seven parts per normal landing rather than twenty detail parts."""
    t = THEMES[theme]
    accent = COLORS['gold'] if shortcut else t['accent']
    model = item('Model', name, parent)
    part(model, 'Walkable', (x, top-1, z), (width, 2, depth), t['surface'], collide=True,
         material='concrete' if theme == 'Skyline' else 'smooth')
    part(model, 'Foundation', (x, top-2.3, z), (width-.7, .6, depth-.7), t['base'], material='metal')
    part(model, 'LandingEdge', (x, top+.035, z+depth/2-.22), (width-.6, .07, .28), accent, material='neon')
    for side in (-1, 1):
        part(model, 'EdgeInset', (x+side*(width/2-.18), top+.035, z), (.12, .07, depth-.6), t['base'])
        beam(model, 'Direction', (x+side*.75, top+.09, z+.2), (x, top+.09, z-.8), .11, accent, 'neon')
    if shortcut:
        part(model, 'RiskStripe', (x, top+.045, z-depth/2+.22), (width-.6, .09, .28), COLORS['gold'], material='neon')
        # A text cue distinguishes dash forks even on Foundry's warm palette.
        sign(model, 'DashRoute', 'DASH', (x,top-.8,z+depth/2+.05),
             (width-.3,1.2,.08), fg=COLORS['gold'])
    return model


def course_route(theme):
    """24 three-jump sections; every primary jump is possible without using Dash.

    Differences in width, lateral line and elevation produce four acts of a race.
    The step length never triples: routes grow through new landings, not scaling.
    """
    route = [dict(index=0, x=0, z=0, width=28, depth=24, top=22, name='LaunchDeck')]
    offsets = {
        'Skyline': (0, -4, 3, 5, -3, 0),
        'Neon': (-3, 4, -5, 3, -3, 4),
        'Grid': (0, 4, -4, 0, -4, 4),
        'Foundry': (3, -4, 0, 4, -3, 0),
        'Zenith': (-3, 0, 4, -4, 3, 0),
    }
    for section in range(24):
        act = section // 6
        bend = offsets[theme][section % 6]
        for step in range(3):
            previous = route[-1]
            # Broad landing every third jump gives space to line up the next act.
            depth = (9, 10, 16)[step]
            gap = (3.5, 4.5, 3.5)[step] + (0, .5, 1, 1)[act]
            width = (15, 13, 21)[step] - (0, 1, 2, 3)[act]
            top = (22, 22.5, 23)[step] + (1 if section % 4 == 2 else 0)
            x = (bend, -bend*.4, 0)[step]
            if section in (4, 10, 16, 22) and step < 2:
                x = 14 if section % 12 < 6 else -14
                width = 15
                gap = 3.5
            # Grid's square silhouette is retained without narrow unfair gaps.
            if theme == 'Grid' and step < 2:
                width = max(10, width)
                depth = width
            p = dict(index=len(route), x=x, z=previous['z']-(previous['depth']+depth)/2-gap,
                     width=width, depth=depth, top=top, name=f'Section{section+1:02d}_Pad{step+1}',
                     section=section+1, act=act+1, gate=section+1 if step == 2 else None, gap=gap)
            route.append(p)
    previous = route[-1]
    route.append(dict(index=73, x=0, z=previous['z']-(previous['depth']+26)/2-4,
                      width=30, depth=26, top=23, name='FinishDeck', gap=4))
    return route


def arch(parent, name, x, z, top, width, accent, text):
    group = item('Model', name, parent)
    for side in (-1, 1):
        part(group, 'Upright', (x+side*width/2, top+7, z), (1.3, 14, 1.5), COLORS['ink'], material='metal')
        part(group, 'Light', (x+side*(width/2-.1), top+7, z+.78), (.13, 12, .07), accent, material='neon')
    sign(group, 'Header', text, (x, top+14.1, z), (width+2, 3.2, 1.5), fg=accent)
    part(group, 'HeaderLine', (x, top+12.4, z+.8), (width+1, .12, .08), accent, material='neon')
    return group


def build_course(theme):
    t = THEMES[theme]
    root = item('Model', theme)
    route = course_route(theme)
    platforms = item('Folder', 'Course', root)
    props = item('Folder', 'Architecture', root)
    gates = item('Folder', 'Gates', root)
    hazards = item('Folder', 'Hazards', root)
    for p in route:
        deck(platforms, p['name'], p['x'], p['z'], p['width'], p['depth'], p['top'], theme)
        if p.get('gate'):
            n = p['gate']
            part(gates, f'Gate{n:02d}', (p['x'], p['top']+6, p['z']),
                 (p['width']+3, 16, p['depth']+1), t['accent'], transparency=1, touch=True)
            # Every sixth section gets a large clear milestone; no forest of text.
            if n % 6 == 0 and n < 24:
                arch(props, f'Sector{n//6+1}', 0, p['z'], p['top'], 38, t['accent'], f'SECTOR {n//6+1:02d}')
            else:
                part(props, 'Milestone', (p['x']+p['width']/2+1.5, p['top']+1.5, p['z']), (.3, 3, .6), t['accent'], material='neon')
    shortcuts = []
    for section in (4, 10, 16, 22):
        prior, ending = route[section*3], route[(section+1)*3]
        edge_start = prior['z']-prior['depth']/2
        edge_end = ending['z']+ending['depth']/2
        clear_span = edge_start-edge_end
        # One deliberate long leap, then one ordinary jump. Never two compulsory
        # dashes inside a cooldown. Its width, not an invisible wall, is the risk.
        depth = clear_span-14.5-3.5
        z = edge_end+3.5+depth/2
        alt = dict(index=100+section, x=0, z=z, width=6.5, depth=depth, top=22.5,
                   name=f'RiskShortcut{section+1:02d}', from_index=prior['index'], to_index=ending['index'],
                   entry_gap=14.5, exit_gap=3.5, required_dash=True)
        deck(platforms, alt['name'], 0, z, 6.5, depth, 22.5, theme, shortcut=True)
        shortcuts.append(alt)
    end = route[-1]
    part(root, 'Start', (0, 26, 5), (5, 1, 5), t['accent'], transparency=1)
    part(root, 'Finish', (0, 28, end['z']-5), (29, 11, 7), t['accent'], transparency=1, touch=True)
    length = abs(end['z'])+83
    center_z = (40+end['z']-43)/2
    part(root, 'Bounds', (0, 49, center_z), (116, 92, length), t['accent'], transparency=1)
    part(hazards, 'KillFloor', (0, 3, center_z), (116, 2, length), t['floor'],
         transparency=1 if theme in ('Skyline', 'Zenith') else 0, touch=True, reflectance=.09 if theme == 'Neon' else 0)
    arch(props, 'StartArch', 0, 8, 22, 31, t['accent'], t['title'])
    arch(props, 'FinishArch', 0, end['z']-5, 23, 30, COLORS['gold'], 'FINISH')
    sign(props, 'StartRule', 'ONE RUN. MAKE IT COUNT.', (0, 25, -6), (20, 1.5, .2), fg=COLORS['white'])
    {'Skyline': skyline_architecture, 'Neon': neon_architecture, 'Grid': grid_architecture,
     'Foundry': foundry_architecture, 'Zenith': zenith_architecture}[theme](props, route)
    COURSE_METADATA[theme] = dict(primary=route, shortcuts=shortcuts,
        gates=[p['index'] for p in route if p.get('gate')], finish=(0, 28, end['z']-5), start=(0, 26, 5),
        bounds=dict(center=(0,49,center_z), size=(116,92,length)),
        course_length_studs=round(abs(end['z']), 2), normal_max_gap=max(p.get('gap',0) for p in route),
        description='74 primary landings; 24 gates; no primary jump requires dash. Gold forks need one dash. Decoration is non-collidable.')
    return root


def skyline_architecture(parent, route):
    count = math.ceil(abs(route[-1]['z'])/76)+1
    for side in (-1, 1):
        for segment in range(count):
            z = 5-segment*76
            x = side*40
            group = item('Model', f'TransitPylon{side}_{segment}', parent)
            part(group, 'LimestoneSpine', (x, 36, z), (7, 50, 39), (199, 215, 225), material='concrete')
            part(group, 'Recess', (x-side*3.55, 36, z), (.12, 30, 30), (63, 88, 109))
            part(group, 'Glass', (x-side*3.64, 37, z), (.1, 24, 25), (148, 206, 226), material='glass', transparency=.32)
            for rib in (-9, 0, 9):
                part(group, 'Rib', (x-side*3.78, 37, z+rib), (.22, 27, .3), (181, 208, 217), material='metal')
            part(group, 'Crown', (x, 62, z), (10, 1.8, 42), (231, 239, 242))
            part(group, 'Line', (x-side*3.8, 23, z), (.14, .25, 33), THEMES['Skyline']['accent'], material='neon')
            if segment % 2 == 0:
                beam(group, 'Brace', (x-side*4, 19, z-14), (x-side*13, 8, z), .65, (110, 142, 163))
                part(group, 'DistantSpire', (side*91, 21, z-28), (19, 75+(segment%3)*14, 31), (132, 168, 191))
                for i in range(3):
                    part(group, 'Cloud', (side*(47+i*12), -3+i, z-12+i*14), (52, 15, 51), (235, 244, 248), shape=0, transparency=.12)
    for n in (6, 12, 18):
        z = route[n*3]['z']
        part(parent, 'TransitBridge', (0, 71, z), (92, 3, 9), (161, 187, 204), material='metal')
        part(parent, 'BridgeStrip', (0, 69.4, z+2), (62, .14, .7), THEMES['Skyline']['accent'], material='neon')
    sign(parent, 'Terminal', 'CLOUDLINE / ARRIVALS', (0, 57, route[-1]['z']-43), (46, 7, 1), bg=(206,222,232), fg=(45,77,100))


def neon_architecture(parent, route):
    count = math.ceil(abs(route[-1]['z'])/68)+1
    palette = ((28, 32, 48), (37, 32, 55), (26, 38, 53))
    for side in (-1, 1):
        for b in range(count):
            z, x = 8-b*68, side*39
            h = 72+(b%3)*14
            group = item('Model', f'AlleyBlock{side}_{b}', parent)
            part(group, 'Building', (x, h/2+3, z), (17, h, 64), palette[b%3], material='concrete')
            part(group, 'Roof', (x, h+3, z), (19, 1.8, 66), (57, 62, 81), material='metal')
            for row in range(3):
                for col in range(3):
                    tint = (221, 175, 129) if (row+col+b)%5 == 0 else (88, 108, 160)
                    part(group, 'Window', (x-side*8.55, 32+row*18, z-20+col*20), (.14, 7, 8), tint, material='neon', transparency=.42)
            part(group, 'ServicePipe', (x-side*9, 19, z), (.55, .55, 61), (87, 80, 110), material='metal')
            part(group, 'Downpipe', (x-side*9, 36, z+26), (.65, 62, .65), (83, 88, 107), material='metal')
            part(group, 'Vent', (x-side*9.6, 29, z-16), (2.3, 4.6, 6), (85, 95, 118), material='metal')
            if b % 3 == 1:
                accent = COLORS['pink'] if side == 1 else COLORS['cyan']
                sign(group, 'BladeSign', ('NIGHT\nSHIFT', 'VOID', '02 /\nA.M.', 'RUN')[(b//3)%4],
                     (side*28.7, 41, z+1), (6, 14, .6), fg=accent)
                lamp = part(group, 'CanopyLight', (side*28, 27, z-15), (4, .2, 11), accent, material='neon')
                light(lamp, 'NeonFill', accent, .6, 19)
    for b in range(0, count, 3):
        z = -35-b*68
        beam(parent, 'Cable', (-30, 61, z), (30, 58, z-4), .15, (9, 13, 23))
        for x in (-20, -10, 0, 10, 20):
            part(parent, 'Lantern', (x, 58.5, z-2), (.9, 1.8, .9), (255, 199, 148), material='neon')
    part(parent, 'TerminalTower', (0, 73, route[-1]['z']-48), (80, 140, 16), (23, 29, 48))
    sign(parent, 'Terminal', 'AFTERHOURS', (0, 51, route[-1]['z']-39), (39, 8, .6), fg=THEMES['Neon']['accent'])


def grid_architecture(parent, route):
    length = abs(route[-1]['z'])+78
    center_z = (35+route[-1]['z']-43)/2
    for side in (-1, 1):
        part(parent, 'GalleryWall', (side*36, 40, center_z), (3, 74, length), (201, 218, 228))
        part(parent, 'Plinth', (side*34.4, 14, center_z), (.12, 20, length-2), (60, 84, 107))
        part(parent, 'TrackLine', (side*34.25, 24, center_z), (.14, .22, length-2), THEMES['Grid']['accent'], material='neon')
        for n in range(math.ceil(length/44)):
            z = 20-n*44
            part(parent, 'Joint', (side*34.3, 47, z), (.12, 57, .18), (161, 187, 205))
            for row in range(2):
                yy = 36+row*22
                part(parent, 'WallTile', (side*34.15, yy, z-20), (.18, 15, 22), (183, 205, 219))
                part(parent, 'Inset', (side*34, yy, z-20), (.13, 12.5, 19.5), (218, 232, 239))
            if n % 3 == 1:
                part(parent, 'GalleryLight', (side*33.7, 70, z-20), (.2, .4, 20), COLORS['white'], material='neon')
        for n in range(3,24,6):
            p = route[n*3]
            part(parent, 'ExhibitCube', (side*28, 34, p['z']), (5, 5, 5), THEMES['Grid']['accent'] if n % 2 else COLORS['gold'], yaw=45)
    for z in (36, route[-1]['z']-43):
        part(parent, 'EndWall', (0, 40, z), (75, 74, 3), (196, 213, 225))
    for n in range(math.ceil(length/44)):
        z = 20-n*44
        part(parent, 'FloorLine', (0, 4.035, z), (68, .07, .15), (72, 91, 115))
    sign(parent, 'Terminal', 'THE GRID', (0, 52, route[-1]['z']-41.4), (36, 8, .15), bg=(44,66,87), fg=THEMES['Grid']['accent'])


def foundry_architecture(parent, route):
    length = abs(route[-1]['z'])
    for side in (-1, 1):
        for n in range(math.ceil(length/82)+1):
            z = 4-n*82
            group = item('Model', f'FoundryBay{side}_{n}', parent)
            part(group, 'SteelWall', (side*40, 40, z), (5, 75, 76), (49, 48, 51), material='metal')
            part(group, 'IBeam', (side*36, 38, z-36), (2, 70, 3), (92, 77, 60), material='metal')
            part(group, 'BaseGirder', (side*35.7, 13, z), (2, 8, 76), (83, 73, 65), material='metal')
            part(group, 'HighPipe', (side*35, 61, z), (2.5, 2.5, 76), (124, 100, 68), material='metal')
            part(group, 'GlowingVent', (side*37.4, 39, z), (.3, 20, 20), (222, 137, 62), material='neon', transparency=.22)
            for rib in (-7, 0, 7):
                part(group, 'VentRib', (side*37.1, 39, z+rib), (.35, 23, 2.4), (41, 40, 47), material='metal')
            part(group, 'Tank', (side*32, 20, z-22), (6, 14, 6), (85, 90, 96), shape=2, roll=90, material='metal')
            part(group, 'TankBand', (side*32, 20, z-22), (.7, 14.3, 6.3), (174, 142, 95), shape=2, roll=90, material='metal')
            if n % 2 == 0:
                beam(group, 'Diagonal', (side*35, 18, z+21), (side*35, 60, z-21), .8, (103, 88, 72))
    for n in (3, 9, 15, 21):
        z = route[n*3]['z']
        part(parent, 'Gantry', (0, 67, z), (82, 5, 9), (101, 84, 64), material='metal')
        for x in (-23, 23):
            part(parent, 'Pendant', (x, 55, z), (.35, 20, .35), (57, 59, 66), material='metal')
            lamp = part(parent, 'WorkLight', (x, 45, z), (8, .5, 3), (255, 204, 137), material='neon')
            light(lamp, 'WarmPool', (255, 188, 100), .7, 27)
    sign(parent, 'Terminal', 'FOUNDRY / EXIT 04', (0, 49, route[-1]['z']-42), (40, 7, 1), fg=THEMES['Foundry']['accent'])


def zenith_architecture(parent, route):
    # Open observatory with restrained star posts and orbit ribs, no asset meshes.
    for side in (-1, 1):
        for n in range(math.ceil(abs(route[-1]['z'])/82)+1):
            z = 5-n*82
            x = side*40
            part(parent, 'ObservatoryPier', (x, 35, z), (5, 51, 11), (69, 88, 124), material='metal')
            part(parent, 'SilverCap', (x, 61, z), (8, 1.7, 14), (165, 184, 211), material='metal')
            part(parent, 'StarLine', (x-side*2.6, 37, z+5), (.12, 34, .28), THEMES['Zenith']['accent'], material='neon')
            part(parent, 'GlassFin', (x-side*3.1, 33, z-17), (.18, 31, 21), (107, 144, 190), material='glass', transparency=.52)
            if n % 2 == 0:
                part(parent, 'DistantIsland', (side*(84+n%3*17), -4, z-21), (30, 27, 50), (61, 82, 120), shape=0)
                part(parent, 'CloudVeil', (side*63, -9, z+12), (78, 13, 69), (109, 135, 177), shape=0, transparency=.55)
        for n in range(13):
            part(parent, 'Star', (side*(60+n%4*19), 70+n%5*11, -60-n*94), (.55, .55, .55), (217, 228, 255), material='neon', shape=0)
    for section in (2, 8, 14, 20):
        z = route[section*3]['z']
        points = [(math.cos(math.radians(a))*44, 30+math.sin(math.radians(a))*44, z) for a in range(0,181,15)]
        for a,b in zip(points, points[1:]):
            beam(parent, 'OrbitRib', a, b, .65, (115, 144, 186))
        part(parent, 'OrbitCrown', (0, 76, z), (3, 3, 3), THEMES['Zenith']['accent'], material='neon', shape=0)
    sign(parent, 'Terminal', 'ZENITH / OBSERVATORY', (0, 49, route[-1]['z']-41), (42, 7, 1), fg=THEMES['Zenith']['accent'])


def ring(parent, name, center, radius, width, rgb, *, segments=32, material='neon'):
    x,y,z = center
    for n in range(segments):
        a, b = math.tau*n/segments, math.tau*(n+1)/segments
        beam(parent, name, (x+math.cos(a)*radius,y,z+math.sin(a)*radius),
             (x+math.cos(b)*radius,y,z+math.sin(b)*radius), width, rgb, material)


def build_lobby():
    """A dark race-club atrium. Interaction labels sit on physical kiosks, not HUD."""
    lobby = item('Model', 'Lobby')
    base = item('Folder', 'Structure', lobby)
    detail = item('Folder', 'Details', lobby)
    cyan, ivory = (107, 226, 230), (232, 235, 231)
    charcoal, navy = (22, 28, 38), (32, 42, 58)
    part(base, 'MainDeck', (0, 20, 91), (148, 4, 110), charcoal, collide=True, material='concrete')
    part(detail, 'Foundation', (0, 16.8, 91), (142, 2.4, 104), (12, 18, 27), material='metal')
    part(detail, 'CentralInlay', (0, 22.035, 88), (64, .07, 91), navy)
    for x in (-33,33):
        part(detail, 'LaneInlay', (x,22.08,88), (.12,.08,92), (63,87,109), material='metal')
    # Tiny joints, rather than a checkerboard, give the large floor believable scale.
    for z in (55,77,99,121,143):
        part(detail, 'FloorJoint', (0,22.075,z), (140,.04,.075), (40,50,64))
    for side in (-1,1):
        part(base, 'SideWall', (side*74,37,91), (2,34,110), (19,25,35), collide=True)
        part(detail, 'WallLower', (side*72.9,26,91), (.15,8,106), (39,50,66))
        part(detail, 'SideGlass', (side*72.8,40,85), (.1,17,74), (73,116,144), material='glass', transparency=.58)
        part(base, 'GalleryRoof', (side*51,55,91), (47,2.5,114), (16,22,31), collide=True)
        part(detail, 'CoveLight', (side*28.6,53.7,91), (.2,.18,106), ivory, material='neon')
        for z in (42,75,108,141):
            part(base,'AtriumColumn',(side*30,37,z),(2.3,30,2.3),(43,53,68),collide=True,material='metal')
            part(detail,'ColumnEdge',(side*29.15,37,z+.85),(.13,25,.13),cyan,material='neon')
        for z in (56,122):
            lamp = part(detail,'RecessedLight',(side*49,53.5,z),(15,.14,2),ivory,material='neon')
            light(lamp,'GalleryFill',(175,205,230),.9,36)
    # Back gallery is quiet architecture. Forward edge is a glass race vista.
    part(base,'BackWall',(0,38,147),(148,36,2),(19,26,37),collide=True)
    part(base,'VistaGlass',(0,30,35),(148,16,1),(92,152,177),collide=True,material='glass',transparency=.82)
    part(detail,'VistaRail',(0,38.2,35),(148,.24,1.2),(111,140,157),material='metal')
    part(detail,'VistaLine',(0,22.12,38),(140,.12,.18),cyan,material='neon')
    sign(detail,'ClubWordmark','D A S H E R',(0,44,145.8),(41,7,.2),face=5,bg=(19,26,37),fg=ivory)
    sign(detail,'ClubCaption','R A C E   C L U B',(0,36.9,145.75),(25,2.1,.2),face=5,bg=(19,26,37),fg=(138,158,180))
    sign(detail,'VistaHeader','FIND YOUR LINE',(0,45,36),(32,3.5,.5),fg=ivory)
    sign(detail,'WelcomeWordmark','D A S H E R',(0,35,40),(24,4,.3),bg=navy,fg=ivory)
    sign(detail,'WelcomeCaption','VOTE.  RACE.  REPEAT.',(0,30.5,40),(23,1.8,.3),bg=navy,fg=cyan)
    for x in (-21,21):
        part(detail,'PortalUpright',(x,32,41),(1,20,1),navy,material='metal')
        part(detail,'PortalLine',(x-.25 if x>0 else x+.25,32,41.55),(.11,17,.08),cyan,material='neon')
    # Spawn emblem and an overhead light sculpture make the centre memorable.
    ring(detail,'SpawnHalo',(0,22.14,87),11,.10,cyan)
    ring(detail,'InnerHalo',(0,22.12,87),9.9,.06,(73,114,137))
    ring(detail,'CanopyHalo',(0,52,87),14,.24,ivory,segments=40)
    fill=part(detail,'AtriumFillSource',(0,44,87),(1,1,1),ivory,transparency=1)
    light(fill,'AtriumFill',(186,211,235),1.4,65)
    for x in (-10,10):
        beam(detail,'SuspensionWire',(x,52,77),(x,61,77),.08,(81,99,122))
        beam(detail,'SuspensionWire',(x,52,97),(x,61,97),.08,(81,99,122))
    for dx in (-1,1):
        beam(detail,'SpawnChevron',(dx*3.5,22.2,88),(0,22.2,83),.25,ivory,'neon')
    # MainDeck supplies collision; an invisible spawn plate must not make avatars float.
    spawn=part(lobby,'SpawnLocation',(0,22.5,87),(7,1,7),cyan,collide=False,cls='SpawnLocation',transparency=1)
    scalar(spawn,'bool','Neutral',True)
    scalar(spawn,'float','Duration',0)
    scalar(spawn,'bool','AllowTeamChangeOnTouch',False)
    kiosks=item('Folder','Kiosks',lobby)
    definitions=[('Shop','SHOP',-53,70,90,cyan),('Inventory','COLLECTION',-53,108,90,ivory),
                 ('Quests','WEEKLY',53,70,-90,(247,204,143)),('Leaderboard','RANKINGS',53,108,-90,(185,181,244))]
    for name,label,x,z,yaw,accent in definitions:
        side=1 if x>0 else -1
        stand=item('Model',name+'Housing',detail)
        part(stand,'Plinth',(x,23,z),(16,2,19),(36,47,62),collide=True)
        part(stand,'BackPanel',(x+side*4,31,z),(2,16,18),(29,39,54),collide=True)
        sign(kiosks,name,label,(x-side*3,30,z),(13,4,.35),yaw=yaw,bg=(23,32,45),fg=accent)
        part(stand,'LightColumn',(x-side*3.2,28,z+8),(.2,10,.22),accent,material='neon')
        part(stand,'FloorLight',(x-side*6.9,24.06,z),(.2,.12,16),accent,material='neon')
        # A simple material object makes each kiosk readable from across the room.
        emblem=part(stand,'DisplayObject',(x-side*1.5,26.8,z),(2.5,2.5,2.5),accent,material='neon',yaw=45,shape=0 if name=='Shop' else 1)
        light(emblem,'KioskGlow',accent,.35,14)
    lounge=item('Folder','Lounge',lobby)
    for x in (-13,13):
        part(lounge,'Bench',(x,24,128),(18,1.1,5),(53,64,80),collide=True)
        part(lounge,'Backrest',(x,25.5,130.2),(18,3,1),(46,57,74),collide=True)
        part(detail,'BenchFoot',(x,22.9,128),(14,1.9,3),(15,20,29),material='metal')
        part(detail,'BenchLight',(x,23.65,125.45),(14,.1,.1),cyan,material='neon')
    for x,z in ((-65,44),(65,44),(-65,135),(65,135)):
        part(detail,'Planter',(x,24,z),(7,4,7),(39,53,68))
        part(detail,'Soil',(x,26.05,z),(6,.1,6),(21,31,37))
        for n in range(4):
            part(detail,'Plant',(x+math.cos(n*1.57)*1.3,29+(n%2),z+math.sin(n*1.57)*1.3),(2.4,6,2.4),(67,115+n*5,105),shape=0)
    # Landing outside the atrium keeps the club grounded without a giant baseplate.
    for side in (-1,1):
        for z in (44,138):
            part(detail,'Substructure',(side*61,2,z),(7,28,7),(29,43,61),material='metal')
        part(detail,'FarTower',(side*125,24,75),(25,90,46),(45,67,94))
    for name,pos in [('CameraStart',(22,46,133)),('CameraEnd',(-16,34,113)),('CameraLookAt',(0,28,78))]:
        part(lobby,name,pos,(1,1,1),cyan,transparency=1)
    return lobby


def build_world():
    global _ids
    _ids=itertools.count(1)
    COURSE_METADATA.clear()
    lobby=build_lobby()
    maps=item('Folder','Maps')
    for name in THEMES:
        maps.append(build_course(name))
    return lobby,maps


if __name__ == '__main__':
    import json
    lobby,maps=build_world()
    counts={m.find("Properties/string[@name='Name']").text:sum(1 for p in m.iter('Item') if p.get('class')=='Part') for m in maps.findall('Item')}
    print(json.dumps({'parts':counts,'lobby_parts':sum(1 for p in lobby.iter('Item') if p.get('class') in ('Part','SpawnLocation')),
                      'courses':{k:{'length':v['course_length_studs'],'finish':v['finish'],'primary_platforms':len(v['primary']),'shortcuts':len(v['shortcuts'])} for k,v in COURSE_METADATA.items()}},indent=2))
