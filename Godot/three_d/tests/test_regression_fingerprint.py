"""A changing model or texture must invalidate a concurrent regression run."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import run_regression


class FingerprintTest(unittest.TestCase):
    def test_asset_changes_are_detected_without_import_cache_noise(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            asset = root / 'Godot/three_d/assets/character.glb'
            asset.parent.mkdir(parents=True)
            asset.write_bytes(b'first model')
            texture = asset.with_suffix('.png')
            texture.write_bytes(b'first texture')
            catalog = root / 'docs/3d-production/phase-1/coverage/transitions.json'
            catalog.parent.mkdir(parents=True)
            catalog.write_text('{}')
            with patch.object(run_regression, 'ROOT', root):
                before = run_regression.fingerprint()
                asset.write_bytes(b'revised model')
                after_model = run_regression.fingerprint()
                self.assertNotEqual(before, after_model)
                texture.write_bytes(b'revised texture')
                after_texture = run_regression.fingerprint()
                self.assertNotEqual(after_model, after_texture)
                asset.with_suffix('.glb.import').write_text('import cache')
                self.assertEqual(after_texture, run_regression.fingerprint())


if __name__ == '__main__':
    unittest.main()
