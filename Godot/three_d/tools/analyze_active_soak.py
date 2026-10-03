"""Analyze current production-AI soak evidence without certifying FPS or leak absence."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BUILD = ROOT / 'output/builds'


def analyze(report, rss, launch, log):
    identity = report['process_id'] == rss['pid'] == launch['process_id']
    files = {}
    for label, path, expected in (
        ('pack', launch['pack_path'], launch['pack_sha256']),
        ('external_script', ROOT / 'Godot/three_d/tools/soak_active_tables.gd', launch['external_script_sha256']),
    ):
        files[label] = hashlib.sha256(Path(path).read_bytes()).hexdigest() == expected
    errors = [line for line in log.splitlines() if any(marker in line for marker in ('ERROR:', 'SCRIPT ERROR:', 'Parse Error:'))]
    samples = report.get('samples', [])
    by_phase = defaultdict(list)
    for sample in samples:
        by_phase[sample['phase']].append(sample)
    phases = {}
    for phase, rows in by_phase.items():
        memories = [r['static_memory_bytes'] for r in rows if r['static_memory_bytes'] > 0]
        phases[phase] = {'samples': len(rows), 'nodes_min': min(r['nodes'] for r in rows),
                         'nodes_max': max(r['nodes'] for r in rows),
                         'static_memory_min_bytes': min(memories) if memories else None,
                         'static_memory_max_bytes': max(memories) if memories else None}
    observed = rss.get('samples', [])
    rss_summary = None
    if observed:
        values = [r['rss_bytes'] for r in observed]
        rss_summary = {'samples': len(values), 'min_bytes': min(values), 'max_bytes': max(values),
                       'first_bytes': values[0], 'last_bytes': values[-1],
                       'last_minus_first_bytes': values[-1] - values[0],
                       'first_report_seconds': observed[0].get('report_elapsed_seconds'),
                       'last_report_seconds': observed[-1].get('report_elapsed_seconds')}
    valid = identity and all(files.values()) and not errors and not report.get('failures', [])
    complete = (valid and report['status'] == 'completed'
                and report.get('elapsed_seconds', 0) >= max(1800, report['duration_target_seconds'])
                and report.get('cycles', 0) > 0 and report.get('ai_transitions', 0) > 0
                and set(report.get('completed_venues', [])) == {'smoky-den', 'high-rise-suite', 'rooftop-club', 'neon-poker-club'}
                and len(observed) > 0)
    return {'status': report['status'], 'evidence_valid': valid, 'duration_gate_met': complete,
            'identity_matches': identity, 'current_file_hashes_match_launch': files,
            'elapsed_seconds': report.get('elapsed_seconds'), 'cycles': report.get('cycles'),
            'ai_transitions': report.get('ai_transitions'), 'completed_venues': report.get('completed_venues'),
            'engine_error_lines': errors, 'failures': report.get('failures', []),
            'render_samples': len(samples),
            'worst_p95_callback_ms': max((r['p95_callback_ms'] for r in samples), default=None),
            'worst_callback_ms': max((r['max_callback_ms'] for r in samples), default=None),
            'phase_samples': phases, 'rss': rss_summary,
            'scope': 'This automatic cargo-table test only. RSS growth may include caches and allocations; phase ranges are descriptive, not matched snapshots. No GPU timing, FPS certification, leak-absence proof, native template/Windows certification, full four-table progression or human game-duration acceptance.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, default=BUILD / 'active-ai-soak-30min.json')
    parser.add_argument('--rss', type=Path, default=BUILD / 'active-ai-soak-rss.json')
    parser.add_argument('--launch', type=Path, default=BUILD / 'active-ai-soak-launch.json')
    parser.add_argument('--log', type=Path, default=BUILD / 'active-ai-soak-30min.log')
    parser.add_argument('--output', type=Path, default=BUILD / 'active-ai-soak-analysis.json')
    args = parser.parse_args()
    result = analyze(json.loads(args.report.read_text()), json.loads(args.rss.read_text()),
                     json.loads(args.launch.read_text()), args.log.read_text())
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
    return 0 if result['evidence_valid'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
