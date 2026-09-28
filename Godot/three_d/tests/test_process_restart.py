"""Exercise production startup across two Godot processes and one disk checkpoint."""
import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
GODOT = shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'


class ProcessRestartTest(unittest.TestCase):
    def test_mid_hand_restart_and_settlement(self):
        scenes = ('smoky-den', 'high-rise-suite', 'rooftop-club', 'neon-poker-club')
        sites = ('cargo-table', 'ledger-cellar', 'mirror-hall', 'embers-table')
        for scene in scenes:
            for site in sites:
                with self.subTest(scene=scene, site=site), tempfile.TemporaryDirectory(prefix='poker-restart-') as home:
                    environment = os.environ.copy()
                    environment['HOME'] = home
                    results = []
                    for phase in ('write', 'restore'):
                        completed = subprocess.run(
                            [GODOT, '--headless', '--path', str(ROOT / 'Godot'), '--script',
                             'res://three_d/tests/process_restart_probe.gd', '--', '--phase=' + phase,
                             '--scene=' + scene, '--site=' + site],
                            text=True, capture_output=True, timeout=20, env=environment,
                        )
                        output = completed.stdout + completed.stderr
                        self.assertEqual(completed.returncode, 0, output)
                        self.assertNotRegex(output, r'(?m)^(?:SCRIPT ERROR|ERROR|Parse Error):')
                        match = re.search(r'(?m)^PROCESS_RESTART (\{.*\})$', output)
                        self.assertIsNotNone(match, output)
                        result = json.loads(match.group(1))
                        self.assertEqual(result['failed'], 0, output)
                        self.assertEqual((result['phase'], result['scene'], result['site']), (phase, scene, site))
                        results.append(result)
                    self.assertGreater(results[0]['turn'], 0)
                    self.assertEqual(results[1]['turn'], results[0]['turn'])
                    self.assertGreater(results[1]['steps'], 0)


if __name__ == '__main__':
    unittest.main()
