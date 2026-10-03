"""Create saves with the retained old Mac pack, then restore with the new pack."""
import hashlib
import json
import subprocess
import tempfile
import zipfile
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENGINE = Path('/Applications/Godot.app/Contents/MacOS/Godot')
PACK_MEMBER = 'Godot德扑酒馆.app/Contents/Resources/Godot德扑酒馆.pck'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    builds = ROOT / 'output/builds'
    archives = {'old': builds / 'TexasPub-before-transform-fix.zip',
                'new': builds / 'TexasPub.zip'}
    output = builds / 'upgrade-checks' / datetime.now().strftime('%Y%m%d-%H%M%S')
    output.mkdir(parents=True, exist_ok=False)
    report = {'scope': 'Old release-pack generated saves restored by new pack on Mac editor runtime; not arbitrary historical migration or native application input.',
              'archive_sha256': {key: digest(path) for key, path in archives.items()},
              'script_sha256': digest(Path(__file__).with_name('verify_export_restart.gd')),
              'results': [], 'passed': False}
    with tempfile.TemporaryDirectory(prefix='texaspub-upgrade-') as temporary:
        packs = {}
        for key, archive in archives.items():
            packs[key] = Path(temporary) / (key + '.pck')
            with zipfile.ZipFile(archive) as package:
                packs[key].write_bytes(package.read(PACK_MEMBER))
        report['pack_sha256'] = {key: digest(path) for key, path in packs.items()}
        for scenario in ('stash', 'table', 'search', 'shopping', 'reservation', 'extracted', 'collateral'):
            save = output / ('texaspub-restart-' + scenario + '.save')
            original_digest = None
            for phase, generation in [('write', 'old'), ('read', 'new')]:
                command = [str(ENGINE), '--headless', '--path', temporary,
                           '--main-pack', str(packs[generation]), '--script',
                           str(Path(__file__).with_name('verify_export_restart.gd')),
                           '--', '--test', phase, scenario, str(save)]
                run = subprocess.run(command, cwd=temporary, capture_output=True,
                                     text=True, timeout=60)
                log = run.stdout + run.stderr
                (output / (scenario + '-' + phase + '.log')).write_text(log)
                ok = run.returncode == 0 and 'ERROR:' not in log and ': PASS' in log
                report['results'].append({'scenario': scenario, 'phase': phase,
                                          'pack': generation, 'exit_code': run.returncode, 'passed': ok})
                if not ok:
                    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
                    raise RuntimeError(f'Upgrade check failed: {scenario}/{phase}; inspect {output}')
                if phase == 'write': original_digest = digest(save)
                elif digest(save) != original_digest:
                    raise RuntimeError('Upgrade check modified the retained old fixture')
            report.setdefault('fixture_sha256', {})[scenario] = original_digest
    report['passed'] = True
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Old-pack to new-pack seven scenarios restore passed: ' + str(output))


if __name__ == '__main__':
    main()
