"""Regression checks for real avatar head bumps missed by point headroom tests."""
import unittest
import math
import world


class RouteClearanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.models={}
        for theme in world.THEMES:
            cls.models[theme]=world.build_course(theme)

    def test_visible_finish_is_beyond_final_platform_and_arrival_apron(self):
        for theme,data in world.COURSE_METADATA.items():
            root=self.models[theme]
            named={n.find("Properties/string[@name='Name']").text:n for n in root.findall('Item')}
            finish,pad=named['Finish'],named['FinishPad']
            self.assertEqual(pad.find("Properties/bool[@name='CanCollide']").text,'true')
            self.assertEqual(pad.find("Properties/float[@name='Transparency']").text,'0')
            def xyz(node,tag,name):
                v=node.find(f"Properties/{tag}[@name='{name}']")
                return tuple(float(v.find(k).text) for k in ('X','Y','Z'))
            sensor_pos=xyz(finish,'CoordinateFrame','CFrame')
            pad_pos=xyz(pad,'CoordinateFrame','CFrame')
            sensor_size=xyz(finish,'Vector3','size')
            pad_size=xyz(pad,'Vector3','size')
            self.assertEqual(sensor_size,(11,7,4))
            self.assertEqual(pad_size,(12,.2,5))
            self.assertEqual(sensor_pos[::2],pad_pos[::2])
            self.assertAlmostEqual(pad_pos[1]+pad_size[1]/2,data['finish_surface'])
            sensor=dict(x=sensor_pos[0],z=sensor_pos[2],width=11,depth=4,yaw=data['finish_yaw'])
            final,crown=data['route'][-2:]
            self.assertGreater(world.rectangle_gap(final,sensor),15,(theme,'premature P064 finish'))
            arrival=data['transitions'][-1]['landing']
            self.assertFalse(world.inside(sensor,arrival[0],arrival[2],2.2),(theme,'premature crown arrival'))
            self.assertFalse(world.inside(sensor,crown['x'],crown['z'],2.2),(theme,'walk to marked goal required'))
            goal=data['finish_walk_target']
            self.assertTrue(world.inside(sensor,goal[0],goal[2]))
            self.assertTrue(world.inside(crown,goal[0],goal[2],-.5))

    def test_open_towers_have_no_enclosing_walls_or_colliding_decoration(self):
        for theme,data in world.COURSE_METADATA.items():
            root=self.models[theme]
            walls=[n for n in root.iter('Item') if n.find("Properties/string[@name='Name']").text.startswith('WallBand')]
            self.assertEqual(len(walls),0)
            self.assertFalse(any(n.find("Properties/string[@name='Name']").text.startswith(('TowerRib','SectorRim','SummitRim')) for n in root.iter('Item')))
            orphan_names={'DepthPool','BaseRing','HangingPlanter','Vine','Leaf','WallStatus','LedgeWall'}
            self.assertFalse(any(n.find("Properties/string[@name='Name']").text in orphan_names for n in root.iter('Item')))
            surfaces=data['route']+data['alternates']+data['catch_ledges']
            max_radius=max(math.hypot(x,z) for p in surfaces for q in world.motion_positions(p) for x,z in world.corners(q))
            self.assertLess(max_radius,73.3,(theme,'route or recovery geometry escaped its existing envelope'))
            # Unrelated architecture must never become an invisible jump blocker.
            for n in root.iter('Item'):
                props=n.find('Properties');collide=props.find("bool[@name='CanCollide']")
                if collide is not None and collide.text=='true':
                    name=props.find("string[@name='Name']").text
                    self.assertTrue(name=='Walkable' or name=='FinishPad',(theme,name))

    def test_normal_jumps_have_real_gaps_without_exhausting_flight_range(self):
        for theme,data in world.COURSE_METADATA.items():
            normal=[e for e in data['transitions'] if not e['updraft']]
            self.assertGreaterEqual(min(e['gap'] for e in normal),4.2)
            self.assertLessEqual(max(e['gap'] for e in normal),8.60001)
            self.assertGreaterEqual(min(e['landing_margin'] for e in normal),1.1)
            self.assertGreater(min(e['range']-e['distance'] for e in normal),.4)
            beam_count=sum(p['kind']=='balance_shortcut' and p['depth']==2.8 for p in data['alternates'])
            self.assertGreaterEqual(beam_count,4,(theme,'missing new beam routes'))

    def test_every_authored_branch_has_an_avatar_corridor(self):
        checked=0
        for theme,data in world.COURSE_METADATA.items():
            transitions=data['transitions']+[e for b in data['branches'] for a in b['alternatives'] for e in a['transitions']]
            self.assertEqual(len(transitions),113)
            for transition in transitions:
                self.assertTrue(transition['corridor_checked'],(theme,transition))
                if transition['updraft']:
                    self.assertGreater(transition['horizontal_delay'],.2)
                    self.assertLess(transition['horizontal_delay'],.25)
                checked+=1
        self.assertEqual(checked,339)

    def test_native_p022_head_bump_uses_clear_departure_lane(self):
        data=world.COURSE_METADATA['Helix'];route=data['route']
        previous,target=route[22],route[23]
        old=world.approach_points(previous,target)
        slabs=route+data['alternates']+data['catch_ledges']
        clear,reason,_=world.jump_corridor(previous,target,(old['takeoff'][0],old['takeoff'][2]),(old['landing'][0],old['landing'][2]),slabs)
        self.assertFalse(clear)
        self.assertEqual(reason,'jump_obstruction:B04_02')
        repaired=world.approach_points(previous,target,obstacles=slabs)
        self.assertTrue(repaired['corridor_adjusted'])
        self.assertGreater(repaired['takeoff'][2],7)
        self.assertLess(repaired['distance'],world.transition_metrics(previous,target)['range'])

    def test_old_shuttle_overhang_is_rejected_even_if_its_center_is_clear(self):
        data=world.COURSE_METADATA['Helix']
        old_main,old_alt=world.authored_sector('Helix',6,1)
        old_surfaces=[p for p in data['route']+data['alternates'] if p['section']!=6]+old_main+old_alt
        with self.assertRaisesRegex(AssertionError,'No clear avatar jump corridor'):
            world.approach_points(data['route'][38],data['route'][39],obstacles=old_surfaces)
        self.assertEqual(data['branches'][5]['quarter'],0)
        current=data['route']+data['alternates']+data['catch_ledges']
        repaired=world.approach_points(data['route'][38],data['route'][39],obstacles=current)
        self.assertTrue(repaired['corridor_checked'])


if __name__=='__main__':unittest.main(verbosity=2)
