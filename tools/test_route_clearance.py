"""Regression checks for real avatar head bumps missed by point headroom tests."""
import unittest
import world


class RouteClearanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        for theme in world.THEMES:
            world.build_course(theme)

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
