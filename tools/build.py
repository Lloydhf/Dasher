"""Build an editable Roblox XML place from reviewed source and hand-authored geometry.

Python standard library only. Run: python tools/build.py
Roblox Studio opens .rbxlx directly; no Studio plugins or HTTP access required.
"""
from pathlib import Path
import argparse
import json
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
_counter = 0

def item(cls, name):
    global _counter
    _counter += 1
    obj = ET.Element('Item', {'class': cls, 'referent': f'DASHER_BUILD_{_counter}'})
    ET.SubElement(obj, 'Properties')
    prop(obj, 'string', 'Name', name)
    return obj

def prop(obj, kind, name, value):
    node = ET.SubElement(obj.find('Properties'), kind, {'name': name})
    if isinstance(value, dict):
        for k, v in value.items():
            ET.SubElement(node, k).text = str(v)
    else:
        node.text = str(value).lower() if isinstance(value, bool) else str(value)
    return node

def cframe(obj, name, pos, yaw=0):
    c,s=math.cos(yaw),math.sin(yaw)
    prop(obj,'CoordinateFrame',name,dict(zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],[*pos,c,0,s,0,1,0,-s,0,c])))

def camera_look_at(obj, pos, target):
    delta=[target[i]-pos[i] for i in range(3)]
    length=math.sqrt(sum(v*v for v in delta))
    f=[v/length for v in delta]
    horizontal=math.sqrt(f[0]*f[0]+f[2]*f[2])
    r=[-f[2]/horizontal,0,f[0]/horizontal]
    u=[r[1]*f[2]-r[2]*f[1],r[2]*f[0]-r[0]*f[2],r[0]*f[1]-r[1]*f[0]]
    values=[*pos,r[0],u[0],-f[0],r[1],u[1],-f[1],r[2],u[2],-f[2]]
    prop(obj,'CoordinateFrame','CFrame',dict(zip(['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22'],values)))
    cframe(obj,'Focus',target)

def script(cls,name,path):
    obj=item(cls,name)
    prop(obj,'ProtectedString','Source',(ROOT/path).read_text(encoding='utf-8'))
    if cls!='ModuleScript': prop(obj,'bool','Disabled',False)
    return obj

def build(output=None, qa=False):
    from world import build_world, COURSE_METADATA
    tree=ET.Element('roblox',{'version':'4','xmlns:xmime':'http://www.w3.org/2005/05/xmlmime','xmlns:xsi':'http://www.w3.org/2001/XMLSchema-instance'})
    ET.SubElement(tree,'External').text='null'
    ET.SubElement(tree,'External').text='nil'
    ws=item('Workspace','Workspace')
    prop(ws,'float','Gravity',196.2)
    prop(ws,'float','FallenPartsDestroyHeight',-120)
    # One active route is cloned at a time. Keep spectate targets replicated in this build.
    prop(ws,'bool','StreamingEnabled',False)
    lobby,maps=build_world()
    ws.append(lobby)
    cam=item('Camera','Camera')
    camera_look_at(cam,(22,46,133),(0,28,78))
    prop(cam,'float','FieldOfView',70)
    ws.append(cam)
    prop(ws,'Ref','CurrentCamera',cam.attrib['referent'])
    tree.append(ws)
    lighting=item('Lighting','Lighting')
    # Explicit legacy serialization fallback prevents Studio interpreting an
    # omitted Technology value as obsolete Compatibility lighting.
    prop(lighting,'token','Technology',4)
    prop(lighting,'token','LightingStyle',0)
    prop(lighting,'bool','PrioritizeLightingQuality',True)
    prop(lighting,'float','ExposureCompensation',-0.15)
    for key,value in [('Brightness',2.4),('ClockTime',0.8),('EnvironmentDiffuseScale',0.65),('EnvironmentSpecularScale',0.75),('ShadowSoftness',0.3)]:
        prop(lighting,'float',key,value)
    prop(lighting,'bool','GlobalShadows',True)
    prop(lighting,'Color3','Ambient',{'R':69/255,'G':82/255,'B':111/255})
    prop(lighting,'Color3','OutdoorAmbient',{'R':86/255,'G':97/255,'B':127/255})
    atmosphere=item('Atmosphere','Atmosphere')
    for key,val in [('Density',0.23),('Offset',0.15),('Haze',0.6),('Glare',0.15)]: prop(atmosphere,'float',key,val)
    prop(atmosphere,'Color3','Color',{'R':0.77,'G':0.85,'B':1})
    prop(atmosphere,'Color3','Decay',{'R':0.45,'G':0.53,'B':0.67})
    lighting.append(atmosphere)
    bloom=item('BloomEffect','Bloom')
    for key,val in [('Intensity',0.18),('Size',24),('Threshold',1.4)]:prop(bloom,'float',key,val)
    lighting.append(bloom)
    tree.append(lighting)
    replicated=item('ReplicatedStorage','ReplicatedStorage')
    shared=item('Folder','Dasher');shared.append(script('ModuleScript','Config','src/shared/Config.luau'));replicated.append(shared);tree.append(replicated)
    storage=item('ServerStorage','ServerStorage');storage.append(maps);tree.append(storage)
    scripts=item('ServerScriptService','ServerScriptService')
    # Server modules remain independent and are embedded automatically.
    for module in sorted((ROOT/'src/server').glob('*.luau')):
        if not module.name.endswith('.server.luau'):
            scripts.append(script('ModuleScript',module.stem,module.relative_to(ROOT)))
    server=script('Script','DasherServer','src/server/DasherServer.server.luau')
    if qa:
        source=server.find('Properties/ProtectedString')
        source.text='if game:GetService("RunService"):IsStudio() then workspace:SetAttribute("DasherTestMode", true) end\n'+source.text
    scripts.append(server)
    if qa and (ROOT/'tools/StudioQA.server.luau').exists(): scripts.append(script('Script','StudioQA','tools/StudioQA.server.luau'))
    tree.append(scripts)
    starter=item('StarterPlayer','StarterPlayer')
    prop(starter,'float','CameraMaxZoomDistance',24)
    prop(starter,'float','CameraMinZoomDistance',7)
    prop(starter,'bool','EnableMouseLockOption',False)
    sp=item('StarterPlayerScripts','StarterPlayerScripts');sp.append(script('LocalScript','DasherClient','src/client/DasherClient.client.luau'));starter.append(sp);tree.append(starter)
    tree.append(item('StarterGui','StarterGui'))
    tree.append(item('SoundService','SoundService'))
    text_chat=item('TextChatService','TextChatService')
    prop(text_chat,'token','ChatVersion',1)
    tree.append(text_chat)
    output=Path(output) if output else ROOT/'Dasher.rbxlx'
    ET.indent(tree,space='  ')
    ET.ElementTree(tree).write(output,encoding='utf-8',xml_declaration=True)
    (ROOT/'docs/map-metrics.json').write_text(json.dumps(COURSE_METADATA,indent=2),encoding='utf-8')
    print(f'Built {output} ({output.stat().st_size:,} bytes, {len(tree.findall(".//Item"))} instances)')
    return output

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output');p.add_argument('--qa',action='store_true');a=p.parse_args();build(a.output,a.qa)

