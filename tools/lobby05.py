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
        """An asset-free, articulated shopkeeper with a consistent Roblox silhouette.

        NPCMotion values bind accessories to the same head/arm transform on the
        client.  Pivot positions are root-local; faces point toward local +Z.
        Nothing in this display rig collides or participates in race physics.
        """
        model=item('Model',page+'_NPC',lobby)
        angle=math.radians(yaw)
        def body(label,px,py,pz,size,rgb,motion=None,**kw):
            pos=(x+math.cos(angle)*px+math.sin(angle)*pz,floor+py,z-math.sin(angle)*px+math.cos(angle)*pz)
            node=part(model,label,pos,size,rgb,yaw=yaw,**kw)
            if motion:value(node,'StringValue','NPCMotion',motion)
            return node
        root=body('HumanoidRootPart',0,3.1,0,(2,2,1),shirt,transparency=1)
        scalar(model,'Ref','PrimaryPart',root.attrib['referent'])
        value(root,'StringValue','MenuPage',page); value(root,'StringValue','NPCName',name)
        roles={'Shop':'Trail artisan','Inventory':'Style curator','Quests':'Garden guide','Leaderboard':'Race steward'}
        value(root,'StringValue','NPCRole',roles[page])
        value(root,'StringValue','NPCStyle',page)
        for label,xyz in [('NPCHeadPivot',(0,1.72,0)),('NPCLeftArmPivot',(-1.15,.9,0)),('NPCRightArmPivot',(1.15,.9,0))]:
            value(root,'Vector3Value',label,xyz)
        prompt=item('ProximityPrompt','StationPrompt',root)
        scalar(prompt,'string','ActionText','Talk')
        scalar(prompt,'string','ObjectText',name)
        scalar(prompt,'float','MaxActivationDistance',10)
        scalar(prompt,'float','HoldDuration',0)
        scalar(prompt,'bool','RequiresLineOfSight',False)
        scalar(prompt,'token','KeyboardKeyCode',101)
        scalar(prompt,'token','GamepadKeyCode',1002)
        skin={'Shop':(217,164,118),'Inventory':(170,112,83),'Quests':(235,185,143),'Leaderboard':(201,151,112)}[page]
        hair={'Shop':(64,46,37),'Inventory':(42,37,52),'Quests':(116,64,40),'Leaderboard':(45,42,40)}[page]
        seam=tuple(max(0,c-25) for c in shirt)
        trousers=(56,66,78) if page!='Quests' else (89,95,65)
        body('Torso',0,3.08,0,(2.15,2.18,1.05),shirt,'Body')
        body('Undershirt',0,3.95,.54,(.82,.42,.12),ivory,'Body')
        body('CollarLeft',-.38,3.91,.58,(.46,.25,.16),seam,'Body',roll=-19)
        body('CollarRight',.38,3.91,.58,(.46,.25,.16),seam,'Body',roll=19)
        body('JacketHem',0,2.02,.02,(2.18,.22,1.08),seam,'Body')
        body('JacketFastener',0,3.08,.55,(.09,1.57,.08),ivory,'Body')
        body('ChestPocket',.62,3.42,.58,(.56,.52,.10),seam,'Body')
        body('PocketEdge',.62,3.68,.65,(.61,.07,.08),ivory,'Body')
        body('NameBadge',-.6,3.54,.62,(.43,.28,.10),accent,'Body')
        body('BadgeLine',-.6,3.55,.68,(.25,.055,.03),ink,'Body')
        for sx,side in ((-1,'Left'),(1,'Right')):
            body(side+'Leg',sx*.56,1.03,0,(.95,2.02,1),trousers)
            body(side+'TrouserCuff',sx*.56,.41,.03,(.98,.24,1.05),seam)
            body(side+'Shoe',sx*.56,.24,.18,(1.07,.44,1.44),ink)
            body(side+'Sole',sx*.56,.09,.19,(1.10,.13,1.49),ivory)
            body(side+'Toe',sx*.56,.27,.69,(1.02,.29,.35),ivory)
            for iz in (.29,.46):body(side+'Lace',sx*.56,.48,iz,(.53,.065,.055),ivory)
            motion=side+'Arm'
            body(side+'Arm',sx*1.49,3.15,.01,(.82,1.88,.96),shirt,motion,roll=sx*7)
            body(side+'Sleeve',sx*1.61,2.35,.02,(.84,.34,.99),seam,motion,roll=sx*7)
            body(side+'Hand',sx*1.65,1.99,.09,(.72,.61,.76),skin,motion,shape=0)
            body(side+'Thumb',sx*1.36,2.04,.39,(.25,.34,.29),skin,motion,shape=0)
        body('WatchBand',-1.64,2.23,.14,(.80,.17,.82),ink,'LeftArm')
        body('WatchFace',-1.64,2.24,.59,(.35,.27,.10),accent,'LeftArm',material='glass')
        # Flat cheek/eye planes read clearly at game distance; a rounded head,
        # little ears and layered hair soften the old featureless mannequin.
        body('Neck',0,4.22,0,(.65,.5,.6),skin,'Head')
        body('Head',0,4.82,0,(1.79,1.76,1.52),skin,'Head',shape=0)
        body('FacePlane',0,4.83,.61,(1.33,1.13,.20),skin,'Head')
        for sx,side in ((-1,'Left'),(1,'Right')):
            body(side+'Ear',sx*.88,4.76,-.03,(.30,.48,.39),skin,'Head',shape=0)
            body(side+'EyeWhite',sx*.35,4.98,.747,(.29,.35,.08),(249,246,235),'Head',shape=0)
            body(side+'Pupil',sx*.35,4.96,.791,(.16,.24,.055),ink,'Head',shape=0)
            body(side+'EyeGlint',sx*.35-.035,5.02,.823,(.045,.061,.025),(255,255,255),'Head',shape=0)
            body(side+'Brow',sx*.35,5.24,.732,(.38,.10,.07),hair,'Head',roll=sx*-7)
            body(side+'Cheek',sx*.58,4.67,.721,(.20,.10,.045),tuple(max(0,c-16) for c in skin),'Head',shape=0)
            body(side+'SmileCorner',sx*.21,4.53,.741,(.12,.075,.04),(108,67,50),'Head',roll=sx*24)
        body('Nose',0,4.76,.77,(.16,.19,.18),skin,'Head',shape=0)
        body('Smile',0,4.48,.739,(.32,.065,.04),(108,67,50),'Head')
        body('HairCrown',0,5.47,-.13,(1.83,.65,1.57),hair,'Head',shape=0)
        body('HairBack',0,5.02,-.62,(1.67,1.13,.33),hair,'Head',shape=0)
        for sx in (-1,1):body('Sideburn',sx*.74,5.1,.08,(.22,.64,.77),hair,'Head')
        for n in range(4):
            body('HairFringe',-.53+n*.35,5.40+(.06 if n%2 else 0),.52,(.45,.39,.30),hair,'Head',roll=-12,shape=0)

        if page=='Shop':
            # Milo works at the trail bench: rolled cap, canvas apron and tools.
            body('WorkCap',0,5.75,-.08,(1.9,.36,1.58),hat,'Head',shape=0)
            body('CapBand',0,5.56,.04,(1.95,.15,1.63),hat,'Head')
            body('CapBrim',0,5.55,.78,(1.92,.11,.63),hat,'Head')
            body('CapPatch',0,5.73,.73,(.38,.24,.06),accent,'Head')
            body('Apron',0,2.95,.61,(1.46,1.91,.15),(174,133,90),'Body')
            for xx in (-.57,.57):body('ApronStrap',xx,3.90,.61,(.17,.57,.12),(174,133,90),'Body')
            body('ApronPocket',0,2.73,.73,(1.02,.56,.13),(151,112,74),'Body')
            body('PocketSeam',0,2.99,.81,(1.05,.07,.07),ivory,'Body')
            body('ArtisanPen',.25,3.05,.82,(.10,.57,.10),accent,'Body',roll=8)
            body('BrassTool',-.23,2.99,.80,(.15,.46,.12),(220,180,101),'Body',roll=-12)
        elif page=='Inventory':
            # Nova's asymmetric hair and headset distinguish the curator.
            body('PonytailTie',.69,5.44,-.58,(.40,.31,.41),accent,'Head',shape=0)
            body('Ponytail',.91,5.20,-.70,(.61,1.16,.64),hair,'Head',shape=0,roll=18)
            body('HeadsetBand',0,5.70,0,(1.88,.14,.39),hat,'Head')
            for sx in (-1,1):
                body('Headphone',sx*.99,4.99,.03,(.31,.60,.66),hat,'Head',shape=0)
                body('HeadphoneInset',sx*1.14,4.99,.04,(.07,.34,.39),accent,'Head',shape=0)
            body('HeadsetMic',.78,4.64,.55,(.11,.11,.75),ink,'Head')
            body('MicTip',.70,4.64,.91,(.25,.16,.16),ink,'Head',shape=0)
            body('Sash',-.1,3.04,.66,(.23,1.94,.14),hat,'Body',roll=-25)
            body('BeltBag',-.55,2.40,.78,(.73,.61,.27),hat,'Body')
            body('BagClasp',-.55,2.46,.94,(.19,.13,.07),accent,'Body')
        elif page=='Quests':
            # Fern carries a field journal; the potting apron matches her garden.
            for n in range(7):
                a=math.pi*n/6
                body('Curl',math.cos(a)*.77,5.49+math.sin(a)*.17,.18,(.56,.52,.59),hair,'Head',shape=0)
            body('Headband',0,5.36,.57,(1.58,.12,.14),(224,187,97),'Head')
            body('LeafClip',.64,5.45,.67,(.34,.50,.10),pale_leaf,'Head',shape=0,roll=-28)
            body('GardenApron',0,2.91,.61,(1.51,1.85,.17),(159,170,105),'Body')
            body('ApronPocket',0,2.73,.73,(1.05,.48,.14),(124,141,79),'Body')
            body('SeedPacket',.31,2.99,.78,(.31,.36,.06),ivory,'Body',roll=8)
            body('JournalCover',-1.72,2.01,.62,(.91,.98,.16),(115,74,49),'LeftArm',roll=8)
            body('JournalPages',-1.72,2.01,.72,(.78,.84,.05),ivory,'LeftArm',roll=8)
            body('JournalBand',-1.72,2.01,.76,(.12,.92,.035),leaf,'LeftArm',roll=8)
        else:
            # Ace is a race official in a varsity jacket, with a lap clipboard.
            body('HairSweep',-.19,5.58,.39,(1.26,.48,.60),hair,'Head',shape=0,roll=9)
            body('JacketStripe',0,2.14,.57,(2.12,.12,.10),ivory,'Body')
            body('StewardPatch',.62,3.44,.67,(.36,.37,.08),(246,206,98),'Body')
            body('WhistleCordLeft',-.16,3.50,.69,(.06,.71,.055),ink,'Body',roll=-13)
            body('WhistleCordRight',.16,3.50,.69,(.06,.71,.055),ink,'Body',roll=13)
            body('Whistle',0,3.13,.73,(.27,.20,.15),(220,226,227),'Body',material='metal')
            body('Clipboard',1.78,2.13,.59,(.97,1.18,.12),(119,88,61),'RightArm',roll=-8)
            body('LapSheet',1.78,2.13,.67,(.82,1.02,.05),ivory,'RightArm',roll=-8)
            body('ClipboardClip',1.73,2.69,.72,(.31,.14,.08),ink,'RightArm')
            for n in range(3):body('LapLine',1.79,2.35-n*.20,.71,(.58,.04,.03),stone,'RightArm')

        # A small physical badge sits by the feet, not over the head/camera.
        badge_x=x+math.cos(angle)*-2.5+math.sin(angle)*.95
        badge_z=z-math.sin(angle)*-2.5+math.cos(angle)*.95
        sign(model,'Nameplate',name,(badge_x,floor+1.12,badge_z),(2.8,.64,.15),yaw=yaw,bg=ink,fg=ivory,title=True)
        return model

    def stall(page,title,x,z,yaw,shirt,hat,name):
        shop=item('Model',page+'Pavilion',lobby)
        a=math.radians(yaw)
        def p(label,px,py,pz,size,rgb,**kw):
            return part(shop,label,(x+math.cos(a)*px+math.sin(a)*pz,floor+py,z-math.sin(a)*px+math.cos(a)*pz),
                        size,rgb,yaw=yaw,**kw)
        p('StallBase',0,.16,0,(18,.32,13),stone)
        p('StallMat',2.2,.34,2.7,(6,.035,5),shirt)
        for xx in (-7.5,7.5):
            p('StallPost',xx,5.9,-4,(.7,11.8,.7),wood)
        p('BackWall',0,3,-4.2,(15,6,.5),wood)
        for xx in range(-7,8):p('BackWallSlat',xx,3,-3.91,(.06,5.7,.07),(102,67,48))
        p('DisplayShelf',0,3.0,-3.13,(14.5,.28,2.0),ivory)
        p('ShelfBracketLeft',-5.8,2.53,-3.6,(.3,.7,.7),ink)
        p('ShelfBracketRight',5.8,2.53,-3.6,(.3,.7,.7),ink)
        roof=tint(p('Awning',0,11.5,0,(18,1,13),shirt),'soft')
        for n in range(9):
            p('AwningStripe',-8+n*2,12.05,0,(.6,.06,13),ivory)
        tint(p('AwningFringe',0,10.85,6.3,(18,1,.4),shirt),'soft')
        # Counter occupies one side: the merchant remains approachable from the
        # open aisle and ten players never have to funnel through a tiny doorway.
        p('SideCounter',-3.9,1.95,2.9,(7.8,3.9,3.4),wood,collide=True)
        p('Countertop',-3.9,4.03,2.9,(8.3,.31,3.8),ivory)
        p('CounterFront',-3.9,2.0,4.64,(7.35,3.2,.13),shirt)
        for xx in (-6.9,-5.4,-3.9,-2.4,-.9):p('CounterFlute',xx,2.0,4.75,(.08,2.8,.09),wood)
        p('CounterKickplate',-3.9,.39,4.74,(7.8,.32,.12),ink)
        p('CoinTray',-5.8,4.31,2.9,(2,.18,1.6),ink)
        for n in range(3):
            p('Coin',-6.45+n*.65,4.48,2.9,(.10,.64,.64),(244,195,74),shape=2,roll=90)
        p('RegisterBase',-1.7,4.31,2.65,(1.45,.25,1.20),ink)
        p('RegisterStand',-1.7,4.75,2.52,(.27,.75,.25),ink)
        p('RegisterScreen',-1.7,5.10,2.54,(1.65,.86,.14),ink)
        p('RegisterGlass',-1.7,5.10,2.63,(1.38,.62,.035),accent,material='neon')
        p('RegisterLine',-1.7,5.10,2.66,(.76,.07,.022),ink)
        p('CounterNotebook',-3.7,4.25,2.5,(1.03,.12,.83),shirt)
        p('NotebookPage',-3.7,4.32,2.5,(.90,.025,.71),ivory)
        p('CounterPen',-3.45,4.37,2.45,(.08,.065,.64),ink)
        for xx in (-6.4,6.4):
            p('PendantStem',xx,9.1,-2.35,(.10,3.2,.10),ink)
            lamp=p('PendantLamp',xx,7.46,-2.35,(1.18,.42,1.18),(252,222,163),material='neon')
            light(lamp,'DisplayLight',(255,222,166),.55,12)
        for n,xx in enumerate((-5.0,-.6,3.8)):
            tone=((111,222,226),(255,199,102),(206,148,249))[n]
            p('DisplayPlinth',xx,3.35,-2.96,(2.6,.34,1.65),ink)
            p('DisplayGlow',xx,3.57,-2.96,(2.35,.10,1.42),tone,material='neon')
            if page=='Shop':
                p('TrailCapsule',xx,4.55,-2.96,(2.05,1.88,1.19),tone,material='glass',transparency=.73)
                # Three stepped fragments suggest a moving trail in a small
                # display case.  Particle sprites use the built-in Studio asset.
                for j in range(4):
                    p('TrailSample',xx-.67+j*.43,4.11+j*.25,-2.81,(.40,.36,.20),tone,material='neon')
                spark=p('SampleEmitter',xx,4.22,-2.74,(.1,.1,.1),tone,transparency=1)
                particles=item('ParticleEmitter','TrailPreview',spark)
                texture=ET.SubElement(particles.find('Properties'),'Content',{'name':'Texture'})
                ET.SubElement(texture,'url').text='rbxasset://textures/particles/sparkles_main.dds'
                scalar(particles,'float','Rate',2)
                scalar(particles,'NumberRange','Lifetime','.7 1.1')
                scalar(particles,'NumberRange','Speed','.5 1.2')
                scalar(particles,'float','LightEmission',.8)
                scalar(particles,'NumberSequence','Size','0 0.13 0 0.55 0.22 0 1 0 0 ')
                scalar(particles,'NumberSequence','Transparency','0 0.18 0 0.65 0.42 0 1 1 0 ')
                rgb=' '.join(str(round(c/255,5)) for c in tone)
                scalar(particles,'ColorSequence','Color',f'0 {rgb} 0 1 {rgb} 0 ')
                scalar(particles,'token','EmissionDirection',1)
            else:
                p('DisplayTorso',xx,4.40,-2.97,(1.08,1.15,.61),tone)
                p('DisplayNeck',xx,5.09,-2.97,(.33,.27,.34),ink)
                p('DisplayScarf',xx,4.78,-2.60,(1.02,.15,.12),ivory)
                p('DisplayBelt',xx,3.91,-2.62,(1.10,.14,.11),ink)
        p('SideShelf',6.25,1.65,-2.55,(2.0,.21,2.8),ivory)
        for j in range(3):p('SupplyBox',6.25,.65+j*.44,-2.65,(1.63,.38,1.60),hat if j%2 else shirt)
        labelpos=(x+math.sin(a)*6.55,floor+12,z+math.cos(a)*6.55)
        sign(shop,'StallTitle',title,labelpos,(14,2.6,.2),yaw=yaw,bg=ink,fg=ivory,title=True)
        npc(name,page,x+math.cos(a)*2.7+math.sin(a)*.55,z-math.sin(a)*2.7+math.cos(a)*.55,yaw,shirt,hat)

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
