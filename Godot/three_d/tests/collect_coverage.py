"""Validate current test evidence; never treat an incomplete catalog as a global denominator."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / 'docs/3d-production/phase-1/coverage/transitions.json'
SUITES = {
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
        if report['catalog_sha256'] != digest(CATALOG) or report['source_sha256'] != hashes or report['test_sha256'] != digest(Path(__file__).parent / test):
            raise ValueError(f'{name}: stale source/catalog/test evidence; rerun the suite')
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
