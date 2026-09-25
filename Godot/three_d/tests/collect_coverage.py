"""Validate current test evidence; never treat an incomplete catalog as a global denominator."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / 'docs/3d-production/phase-1/coverage/transitions.json'
SUITES = {
    'persistence-io': ('save_store_test.gd', {'persistence_io'}),
    'persistence-capture': ('persistence_capture_coverage_test.gd', {'persistence_capture'}),
    'persistence-restore': ('world_restore_atomic_test.gd', {'persistence_restore'}),
    'persistence-run': ('run_restore_bounds_test.gd', {'persistence_run'}),
    'persistence-table': ('table_checkpoint_test.gd', {'persistence_table'}),
    'persistence-replay': ('world_rng_replay_test.gd', {'persistence_replay'}),
    'poker-blind': ('poker_blind_coverage_test.gd', {'poker_blind'}),
    'run-variant': ('run_variant_coverage_test.gd', {'run_variant'}),
    'signal': ('signal_coverage_test.gd', {'signal'}),
    'world': ('world_coverage_test.gd', {'world'}),
    'world-focus-out': ('world_focus_out_test.gd', {'world'}),
    'world-close-request': ('world_close_request_test.gd', {'world'}),
    'player-input': ('player_input_coverage_test.gd', {'player'}),
    'queue': ('short_stack_queue_test.gd', {'queue'}),
    'ending': ('table_endings_test.gd', {'ending'}),
    'payout': ('payout_coverage_test.gd', {'payout'}),
    'poker_progress': ('poker_progress_coverage_test.gd', {'poker_progress'}),
    'poker_action': ('poker_action_coverage_test.gd', {'poker_action'}),
    'poker_discount': ('poker_discount_coverage_test.gd', {'poker_discount'}),
    'poker_guard': ('poker_guard_coverage_test.gd', {'poker_guard'}),
    'advanced': ('advanced_coverage_test.gd', {'advanced'}),
    'reservation': ('reservation_coverage_test.gd', {'reservation'}),
    'tool': ('tool_coverage_test.gd', {'tool'}),
    'service': ('service_coverage_test.gd', {'service'}),
    'settlement': ('settlement_coverage_test.gd', {'settlement'}),
    'entry': ('entry_coverage_test.gd', {'entry'}),
    'search': ('search_coverage_test.gd', {'search'}),
    'route-guard': ('route_guard_coverage_test.gd', {'route_guard'}),
    'transfer': ('transfer_coverage_test.gd', {'transfer'}),
    'lifecycle': ('lifecycle_coverage_test.gd', {'start', 'reset', 'discover', 'extract', 'abandon', 'pressure'}),
}

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def collect():
    catalog = json.loads(CATALOG.read_text())
    ids = [row['id'] for row in catalog['transitions']]
    if len(ids) != len(set(ids)):
        raise ValueError('Duplicate catalog IDs')
    hashes = {p.name: digest(p) for p in (ROOT / 'Godot/three_d/rules').iterdir() if p.suffix in {'.gd', '.json'}}
    hits = set()
    for name, (test, prefixes) in SUITES.items():
        report = json.loads((ROOT / f'output/3d/{name}-coverage.json').read_text())
        expected = {i for i in ids if i.split('.')[0] in prefixes}
        if name == 'world':
            expected.discard('world.window_focus_out')
            expected.discard('world.window_close_request')
        if name == 'world-focus-out':
            expected = {'world.window_focus_out'}
        if name == 'world-close-request':
            expected = {'world.window_close_request'}
        if name == 'player-input' and report.get('player_source_sha256') != digest(ROOT / 'Godot/three_d/scripts/player.gd'):
            raise ValueError('player-input: stale player script evidence; rerun the suite')
        if name == 'player-input':
            expected.update({'world.prop_on', 'world.raycast_unfocused', 'world.focus_controls_disabled'})
        if name == 'poker_action':
            expected.update(i for i in ids if i == 'poker.player_raise_pattern')
        if report['catalog_sha256'] != digest(CATALOG) or report['source_sha256'] != hashes or report['test_sha256'] != digest(Path(__file__).parent / test):
            raise ValueError(f'{name}: stale source/catalog/test evidence; rerun the suite')
        if name in ('world', 'world-focus-out', 'world-close-request', 'persistence-restore', 'persistence-capture'):
            source_names = ('world.gd', 'player.gd', 'scene_props.gd', 'interactable.gd') if name in ('world', 'world-focus-out', 'world-close-request') else (('world.gd',) if name == 'persistence-capture' else ('world.gd', 'player.gd', 'scene_props.gd'))
            world_sources = {name: digest(ROOT / 'Godot/three_d/scripts' / name) for name in source_names}
            if report.get('world_source_sha256') != world_sources:
                raise ValueError('world: stale world script evidence; rerun the suite')
        if report['failures'] or report['missing'] or set(report['hits']) != expected or report['numerator'] != len(expected) or report['denominator'] != len(expected):
            raise ValueError(f'{name}: failed, missing or inconsistent evidence')
        hits.update(expected)
    result = {
        'catalog_status': catalog['status'],
        'catalogued_outcomes': len(ids),
        'verified_outcomes': len(hits),
        'unverified_catalogued_ids': sorted(set(ids) - hits),
        'pending_families': catalog['pending_families'],
        'overall_state_transition_coverage': None,
        'note': 'Global denominator is unfinished. No Phase 1 coverage gate claimed.',
    }
    (ROOT / 'output/3d/coverage-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(f'CURRENT_EVIDENCE verified={len(hits)} catalogued={len(ids)} global_coverage=unavailable')
    return result

if __name__ == '__main__':
    collect()
