import json
import unittest
from pathlib import Path
from unittest.mock import patch

import collect_coverage as coverage


class CoverageEvidenceTests(unittest.TestCase):
    def test_current_evidence_does_not_claim_global_completion(self):
        result = coverage.collect()
        self.assertEqual(result['catalogued_outcomes'], result['verified_outcomes'])
        self.assertEqual(result['catalogued_outcomes'], 388)
        self.assertEqual(result['catalog_status'], 'incomplete_catalog')
        self.assertEqual(set(result['pending_families']), {'poker', 'world', 'persistence'})
        self.assertTrue(all(not rows for rows in result['pending_families'].values()))
        self.assertIsNone(result['overall_state_transition_coverage'])

    def test_rng_negative_control_is_not_a_transition(self):
        catalog = json.loads(coverage.CATALOG.read_text())
        transition_ids = {row['id'] for row in catalog['transitions']}
        controls = {row['id']: row for row in catalog['verification_controls']}
        self.assertNotIn('persistence_replay.rng_negative_control', transition_ids)
        self.assertFalse(controls['persistence_replay.rng_negative_control']['counted_as_state_transition'])

    def test_route_cash_variants_share_one_transition(self):
        catalog = json.loads(coverage.CATALOG.read_text())
        transition_ids = {row['id'] for row in catalog['transitions']}
        retired = {row['id']: row['merged_into'] for row in catalog['retired_transition_ids']}
        self.assertIn('route_guard.cash_general', transition_ids)
        for suffix in ['fixed', 'service-stairs', 'river-launch', 'dropbag-cash', 'dropbag-valuables']:
            old_id = 'route_guard.cash_' + suffix
            self.assertNotIn(old_id, transition_ids)
            self.assertEqual(retired[old_id], 'route_guard.cash_general')

    def test_changed_source_catalog_or_test_is_rejected(self):
        original_digest = coverage.digest
        for changed in [coverage.CATALOG, coverage.ROOT / 'Godot/three_d/rules/routes.gd', coverage.ROOT / 'Godot/three_d/scripts/world.gd', Path(coverage.__file__).parent / 'lifecycle_coverage_test.gd', Path(coverage.__file__).parent / 'save_store_test.gd', Path(coverage.__file__).parent / 'world_restore_atomic_test.gd', Path(coverage.__file__).parent / 'world_rng_replay_test.gd']:
            with self.subTest(changed=changed):
                with patch.object(coverage, 'digest', side_effect=lambda path: 'stale' if path == changed else original_digest(path)):
                    with self.assertRaisesRegex(ValueError, 'stale'):
                        coverage.collect()

    def test_failed_missing_or_inflated_evidence_is_rejected(self):
        report_path = coverage.ROOT / 'output/3d/transfer-coverage.json'
        original_read = Path.read_text
        for defect in ['failure', 'missing', 'count', 'invented_hit']:
            altered = json.loads(original_read(report_path))
            if defect == 'failure':
                altered['failures'] = ['fixture failure']
            elif defect == 'missing':
                altered['hits'].pop(next(iter(altered['hits'])))
            elif defect == 'count':
                altered['numerator'] += 1
            else:
                altered['hits']['transfer.invented'] = {}
            with self.subTest(defect=defect):
                def read(path, *args, **kwargs):
                    return json.dumps(altered) if path == report_path else original_read(path, *args, **kwargs)
                with patch.object(Path, 'read_text', read):
                    with self.assertRaisesRegex(ValueError, 'inconsistent'):
                        coverage.collect()


if __name__ == '__main__':
    unittest.main()
