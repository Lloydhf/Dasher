"""Hand-built garden atrium, vendors and fountain; no external asset dependency."""
import math
import xml.etree.ElementTree as ET


def build_lobby():
    from world import item, part, scalar, vector, color, value, light, beam, sign, circle_ring

    lobby = item('Model', 'Lobby')
    structure = item('Folder', 'Architecture', lobby)
    garden = item('Folder', 'Garden', lobby)
    decor = item('Folder', 'Details', lobby)
    floor, center_z = 64, 158
    ivory, stone, ink = (237, 228, 208), (184, 173, 150), (36, 48, 57)
    wood, leaf, pale_leaf = (125, 83, 57), (77, 138, 94), (128, 181, 116)
    accent, water = (111, 213, 202), (76, 190, 218)

    def tint(node, slot='accent'):
        value(node, 'StringValue', 'LobbyTint', slot)
        return node

    def cylinder(parent, name, x, y, z, radius, height, rgb, collide=False, **kw):
        return part(parent, name, (x, y, z), (height, radius*2, radius*2), rgb,
                    shape=2, roll=90, collide=collide, **kw)

    # A broad, open plaza allows ten avatars to mingle without narrow queues.
    cylinder(structure, 'AtriumFoundation', 0, floor-3.6, center_z, 61, 6, ink, True)
    cylinder(structure, 'LimestonePlaza', 0, floor-.4, center_z, 59, .8, ivory, True)
    circle_ring(decor, 'BrassInlay', (0, floor+.025, center_z), 38, .09, (197, 162, 93), segments=56)
    circle_ring(decor, 'OuterInlay', (0, floor+.03, center_z), 55, .12, stone, segments=64)
    # Radial stone paving is flush; none of the decoration trips the player.
    for n in range(12):
        a = math.tau*n/12
        beam(decor, 'PavingJoint', (math.sin(a)*14,floor+.018,center_z+math.cos(a)*14),
             (math.sin(a)*54,floor+.018,center_z+math.cos(a)*54), .08, stone, 'smooth')
    for n in range(32):
        a = math.tau*n/32
        x,z=math.sin(a)*58.5,center_z+math.cos(a)*58.5
        part(structure,'Balustrade',(x,floor+2.4,z),(11.6,4.8,.6),stone,
             yaw=math.degrees(a),collide=True)
        part(decor,'Coping',(x,floor+4.9,z),(11.8,.35,.85),ivory,yaw=math.degrees(a))
        if n%4==0:
            p=part(decor,'Lantern',(x,floor+6,z),(1.2,1.8,1.2),(254,221,146),material='neon')
            light(p,'WarmLight',(255,215,153),.65,16)

    # Tiered fountain: visible water, a basin and restrained animated spray.
    fountain=item('Model','Fountain',lobby)
    cylinder(fountain,'FountainPlinth',0,floor+.4,center_z,11,.8,stone,True)
    cylinder(fountain,'Basin',0,floor+1,center_z,9.8,.5,(95,126,133),True)
    cylinder(fountain,'Water',0,floor+1.34,center_z,9.5,.12,water,False,material='glass',transparency=.23)
    for n in range(20):
        a=math.tau*n/20
        part(fountain,'BasinRim',(math.sin(a)*10,floor+1.45,center_z+math.cos(a)*10),
             (3.3,1.5,1),ivory,collide=True,yaw=math.degrees(a))
    cylinder(fountain,'Stem',0,floor+3.7,center_z,1.45,6.5,ivory,True)
    cylinder(fountain,'UpperBowl',0,floor+5.8,center_z,4.1,.7,stone)
    cylinder(fountain,'UpperWater',0,floor+6.18,center_z,3.9,.08,water,material='glass',transparency=.15)
    cylinder(fountain,'TopSpout',0,floor+6.7,center_z,.55,1.4,ivory)
    nozzle=part(fountain,'SprayNozzle',(0,floor+7.5,center_z),(.2,.2,.2),water,transparency=1)
    emitter=item('ParticleEmitter','WaterSpray',nozzle)
    texture=ET.SubElement(emitter.find('Properties'),'Content',{'name':'Texture'})
    ET.SubElement(texture,'url').text='rbxasset://textures/particles/sparkles_main.dds'
    scalar(emitter,'NumberRange','Lifetime','0.65 1.05')
    scalar(emitter,'NumberRange','Speed','6 9')
    scalar(emitter,'float','Rate',24)
    scalar(emitter,'float','LightEmission',.15)
    scalar(emitter,'NumberSequence','Size','0 0.11 0 0.6 0.19 0 1 0.02 0 ')
    scalar(emitter,'NumberSequence','Transparency','0 0.15 0 0.8 0.35 0 1 1 0 ')
    scalar(emitter,'ColorSequence','Color','0 0.6 0.88 1 0 1 0.8 0.95 1 0 ')
    vector(emitter,'Acceleration',(0,-18,0))
    spread=ET.SubElement(emitter.find('Properties'),'Vector2',{'name':'SpreadAngle'})
    ET.SubElement(spread,'X').text='28';ET.SubElement(spread,'Y').text='28'
    scalar(emitter,'token','EmissionDirection',1)
    # Eight shaped glass streams descend from the upper bowl.
    for n in range(8):
        a=math.tau*n/8
        for j in range(5):
            t=j/4; r=3.3+2.7*t; y=floor+6.05-4.6*t*t
            droplet=part(fountain,'WaterArc',(math.sin(a)*r,y,center_z+math.cos(a)*r),(.22,.6,.22),
                         water,material='glass',transparency=.35)
    ring=tint(cylinder(decor,'FountainLightRing',0,floor+.83,center_z,11.15,.08,accent,material='neon'))
    light(ring,'FountainGlow',accent,.45,24)

    def planter(x,z,scale=1):
        cylinder(garden,'TerracottaPot',x,floor+1.05*scale,z,2.3*scale,2.1*scale,(165,104,77))
        cylinder(garden,'PotRim',x,floor+2.04*scale,z,2.55*scale,.35*scale,(193,132,95))
        cylinder(garden,'Soil',x,floor+2.24*scale,z,2.2*scale,.1*scale,(70,65,49))
        for n in range(5):
            a=math.tau*n/5
            part(garden,'BroadLeaf',(x+math.sin(a)*1.35*scale,floor+3.2*scale,z+math.cos(a)*1.35*scale),
                 (1.8*scale,2.8*scale,.65*scale),pale_leaf if n%2 else leaf,shape=0,yaw=math.degrees(a),roll=25)

    # Floating garden canopy stays above head height, leaving clear sightlines.
    for x in (-47,47):
        for z in (center_z-30,center_z+30):
            part(structure,'PergolaColumn',(x,floor+13,z),(1.8,26,1.8),wood,collide=True)
            cylinder(decor,'ColumnFoot',x,floor+1,z,2,2,stone)
            planter(x-4*(1 if x>0 else -1),z,1)
        part(decor,'PergolaBeam',(x,floor+26.6,center_z),(2.6,1.6,65),wood)
        for n in range(9):
            z=center_z-28+n*7
            part(decor,'CanopyRafter',(x,floor+27.7,z),(15,.7,1),wood)
            for j in range(3):
                xx=x+(j-1)*4.8
                part(garden,'CanopyLeaves',(xx,floor+28.1,z),(6.2,2.1,8.1),leaf if (n+j)%2 else pale_leaf,shape=0)
            # Suspended vines with overlapping leaf clusters, no collision.
            length=5+(n%3)*2.1
            xx=x+(-5 if x>0 else 5)
            part(garden,'HangingVine',(xx,floor+27-length/2,z),(.18,length,.18),leaf)
            for j in range(4):
                part(garden,'VineLeaf',(xx+(.45 if j%2 else -.45),floor+26-j*length/4,z),
                     (1.3,1.8,.35),pale_leaf,yaw=n*37,roll=20 if j%2 else -20,shape=0)

    def npc(name,page,x,z,yaw,shirt,hat):
        model=item('Model',page+'_NPC',lobby)
        angle=math.radians(yaw)
        def body(label,px,py,pz,size,rgb,**kw):
            pos=(x+math.cos(angle)*px+math.sin(angle)*pz,floor+py,z-math.sin(angle)*px+math.cos(angle)*pz)
            return part(model,label,pos,size,rgb,yaw=yaw,**kw)
        root=body('HumanoidRootPart',0,3.1,0,(2,2,1),shirt,transparency=1)
        scalar(model,'Ref','PrimaryPart',root.attrib['referent'])
        value(root,'StringValue','MenuPage',page); value(root,'StringValue','NPCName',name)
        prompt=item('ProximityPrompt','StationPrompt',root)
        scalar(prompt,'string','ActionText','Browse' if page in ('Shop','Inventory') else 'Talk')
        scalar(prompt,'string','ObjectText',name)
        scalar(prompt,'float','MaxActivationDistance',10)
        scalar(prompt,'float','HoldDuration',0)
        scalar(prompt,'bool','RequiresLineOfSight',False)
        scalar(prompt,'token','KeyboardKeyCode',101)
        scalar(prompt,'token','GamepadKeyCode',1002)
        body('Torso',0,3.05,0,(2.15,2.2,1.05),shirt)
        body('JacketTrim',0,2.3,.56,(2.22,.22,.12),ivory)
        body('LeftLeg',-.56,1,0,(.95,2,1),ink)
        body('RightLeg',.56,1,0,(.95,2,1),ink)
        body('LeftShoe',-.56,.23,.18,(1.05,.45,1.4),ivory)
        body('RightShoe',.56,.23,.18,(1.05,.45,1.4),ivory)
        body('LeftArm',-1.6,3.05,0,(.9,2,.95),shirt,roll=-8)
        body('RightArm',1.6,3.15,0,(.9,2,.95),shirt,roll=12)
        skin=(229,178,125)
        body('LeftHand',-1.72,2.1,.04,(.8,.6,.85),skin)
        body('RightHand',1.78,2.28,.04,(.8,.6,.85),skin)
        head=body('Head',0,4.82,0,(1.8,1.8,1.5),skin,shape=0)
        body('EyeL',-.35,4.97,.704,(.14,.23,.1),ink)
        body('EyeR',.35,4.97,.704,(.14,.23,.1),ink)
        body('Smile',0,4.51,.735,(.52,.1,.08),(109,70,49))
        body('Hair',0,5.56,-.05,(1.9,.5,1.6),hat)
        body('Cap',0,5.85,.03,(2.02,.25,1.8),hat)
        body('Brim',0,5.72,.79,(2.2,.15,.65),hat)
        body('Badge',.6,3.56,.58,(.4,.55,.09),accent)
        # A simple physical sign keeps the NPC identity readable without a HUD cloud.
        plaque=sign(model,'Nameplate',name,(x,floor+7.25,z),(8,1.3,.2),yaw=yaw,bg=ink,fg=ivory,title=True)
        return model

    def stall(page,title,x,z,yaw,shirt,hat,name):
        shop=item('Model',page+'Pavilion',lobby)
        a=math.radians(yaw)
        def p(label,px,py,pz,size,rgb,**kw):
            return part(shop,label,(x+math.cos(a)*px+math.sin(a)*pz,floor+py,z-math.sin(a)*px+math.cos(a)*pz),
                        size,rgb,yaw=yaw,**kw)
        p('StallBase',0,.16,0,(18,.32,13),stone)
        for xx in (-7.5,7.5):
            p('StallPost',xx,5.9,-4,(.7,11.8,.7),wood)
        p('BackWall',0,3,-4.2,(15,6,.5),wood)
        for xx in (-5,0,5): p('Shelf',xx,4,-3.35,(4.5,.3,1.7),ivory)
        roof=tint(p('Awning',0,11.5,0,(18,1,13),shirt),'soft')
        for n in range(9):
            p('AwningStripe',-8+n*2,12.05,0,(.6,.06,13),ivory)
        tint(p('AwningFringe',0,10.85,6.3,(18,1,.4),shirt),'soft')
        p('SideCounter',-5.6,2.1,2,(3.5,4.2,4),wood,collide=True)
        p('Countertop',-5.6,4.4,2,(4,.35,4.6),ivory)
        p('CoinTray',-5.6,4.75,2,(2,.25,1.6),ink)
        for n in range(3):
            p('Coin',-6.25+n*.65,5,2,(.12,.75,.75),(244,195,74),shape=2,roll=90)
        labelpos=(x+math.sin(a)*6.55,floor+12,z+math.cos(a)*6.55)
        sign(shop,'StallTitle',title,labelpos,(14,2.6,.2),yaw=yaw,bg=ink,fg=ivory,title=True)
        npc(name,page,x,z+1,yaw,shirt,hat)

    stall('Shop','TRAILS',-32,center_z-15,25,(57,141,144),(36,76,92),'MILO')
    stall('Inventory','LOCKER',32,center_z-15,-25,(131,109,172),(71,58,104),'NOVA')
    npc('FERN','Quests',-30,center_z+27,140,(117,159,94),(153,112,69))
    npc('ACE','Leaderboard',30,center_z+27,-140,(190,139,70),(68,69,81))
    for x in (-30,30):
        for dz in (-2,2):
            part(decor,'GardenBench',(x,floor+1.8,center_z+21+dz),(11,.7,1.3),wood,collide=True)
        for xx in (-4,4):part(decor,'BenchFoot',(x+xx,floor+.9,center_z+21),(1,1.8,4.8),ink)
    for x,z in ((-19,center_z-38),(19,center_z-38),(-43,center_z+14),(43,center_z+14),(-17,center_z+43),(17,center_z+43)):
        planter(x,z,1.25)

    # Arrival arch frames the active tower; clear portal-like language, no fake buttons.
    for x in (-16,16):
        part(structure,'ArrivalPillar',(x,floor+10.5,center_z-45),(2.5,21,2.5),ivory,collide=True)
        tint(part(decor,'ArrivalLight',(x,floor+12,center_z-43.68),(.32,15,.12),accent,material='neon'))
    part(decor,'ArrivalLintel',(0,floor+21.3,center_z-45),(35,2,3),wood)
    sign(decor,'Wordmark','DASHER',(0,floor+21.4,center_z-43.38),(27,4,.2),bg=ink,fg=ivory,title=True)
    sign(decor,'Submark','RACE TO THE SUMMIT',(0,floor+17.9,center_z-43.38),(19,1.6,.2),bg=ink,fg=accent)
    spawn=part(lobby,'SpawnLocation',(0,floor+.5,center_z+27),(10,1,10),ivory,cls='SpawnLocation',transparency=1)
    scalar(spawn,'bool','Neutral',True);scalar(spawn,'float','Duration',0)
    scalar(spawn,'bool','AllowTeamChangeOnTouch',False)
    for n in range(10):
        x=(n%5-2)*4.3;z=center_z+29+(n//5)*4.3
        tint(cylinder(decor,'ArrivalMarker',x,floor+.04,z,.75,.06,accent,material='neon'))
    for name,pos in [('CameraStart',(61,107,center_z+64)),('CameraEnd',(27,84,center_z+47)),('CameraLookAt',(0,72,center_z-5))]:
        part(lobby,name,pos,(1,1,1),ivory,transparency=1)
    return lobby
