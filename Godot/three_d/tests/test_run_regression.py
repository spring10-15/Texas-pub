import unittest
from run_regression import passed


class RegressionVerdictTests(unittest.TestCase):
    def test_success_summaries(self):
        self.assertTrue(passed(0, 'SUITE {"checks":5,"failed":0,"failures":[]}\n'))
        self.assertTrue(passed(0, 'SUITE checks=5 failures=[]\n'))
        self.assertTrue(passed(0, 'SUITE checks=5 failed=0\n'))

    def test_zero_exit_does_not_hide_script_error(self):
        self.assertFalse(passed(0, 'SUITE checks=5 failures=[]\nSCRIPT ERROR: bad type\n'))

    def test_missing_or_failed_summary(self):
        for code, log in [(0, 'Godot Engine started'), (1, 'SUITE checks=5 failures=[]'),
                          (0, 'SUITE checks=5 failed=1'), (0, 'SUITE {"failed":1}'),
                          (0, 'SUITE checks=5 failures=["broken"]')]:
            with self.subTest(code=code, log=log):
                self.assertFalse(passed(code, log))
