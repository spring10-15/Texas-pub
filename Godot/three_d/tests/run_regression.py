"""Run every Godot regression once; capture tools and manual probes are excluded."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

TESTS = Path(__file__).resolve().parent
ROOT = TESTS.parents[2]
EXTRA = {'smoke.gd', 'table_integration.gd', 'table_parity.gd', 'two_tables.gd'}
EXCLUDED = {'capture.gd', 'capture_table.gd', 'difficulty_probe.gd'}


def passed(code, log):
    if code != 0 or re.search(r'(?m)^(?:SCRIPT ERROR|ERROR|Parse Error):', log):
        return False
    summaries = re.findall(r'(?m)^[A-Z0-9_]+ (.+)$', log)
    if not summaries:
        return False
    summary = summaries[-1]
    if summary.startswith('{'):
        try:
            data = json.loads(summary)
            return data.get('failed') == 0 and not data.get('failures')
        except ValueError:
            return False
    return bool(re.search(r'\b(?:failed=0(?:\s|$)|failures=\[\])', summary))


def fingerprint():
    paths = [p for p in (ROOT / 'Godot/three_d').rglob('*')
             if p.suffix in {'.gd', '.py', '.json', '.tscn'} and 'assets' not in p.parts]
    paths.append(ROOT / 'docs/3d-production/phase-1/coverage/transitions.json')
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--timeout', type=int, default=90, help='Timeout per Godot suite in seconds')
    args = parser.parse_args()
    scripts = sorted(p for p in TESTS.glob('*.gd') if p.name.endswith('_test.gd') or p.name in EXTRA)
    unknown = {p.name for p in TESTS.glob('*.gd')} - {p.name for p in scripts} - EXCLUDED
    if unknown:
        parser.error('Classify new scripts before running: ' + ', '.join(sorted(unknown)))
    output = ROOT / 'output/3d/regression' / time.strftime('%Y%m%d-%H%M%S')
    output.mkdir(parents=True, exist_ok=False)
    before = fingerprint()
    results = []
    for script in scripts:
        command = [args.godot, '--headless', '--path', str(ROOT / 'Godot'), '--script',
                   'res://three_d/tests/' + script.name, '--', '--test']
        start = time.monotonic()
        try:
            process = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
            code, log = process.returncode, process.stdout + process.stderr
            status = 'PASS' if passed(code, log) else 'FAIL'
        except subprocess.TimeoutExpired as error:
            code, status = None, 'TIMEOUT'
            log = (error.stdout or b'').decode(errors='replace') + (error.stderr or b'').decode(errors='replace')
        (output / (script.stem + '.log')).write_text(log)
        results.append(dict(test=script.name, status=status, exit_code=code,
                            seconds=round(time.monotonic()-start, 2), command=command))
        print(f'{status}: {script.name}', flush=True)
    unit = subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', str(TESTS), '-p', 'test_*.py'], capture_output=True, text=True, timeout=30)
    (output / 'python-tests.log').write_text(unit.stdout + unit.stderr)
    unchanged = before == fingerprint()
    report = dict(results=results, excluded=sorted(EXCLUDED), source_sha256=before,
                  sources_unchanged=unchanged, python_exit_code=unit.returncode,
                  passed=unchanged and unit.returncode == 0 and all(r['status'] == 'PASS' for r in results),
                  scope='Regression only; does not establish global transition coverage or human playtest gates.')
    (output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(f'Report: {output / "report.json"}')
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
