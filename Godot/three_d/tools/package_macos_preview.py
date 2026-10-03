"""Include the standalone guide and checksums in the existing Mac preview ZIP."""
import hashlib
import json
import os
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PACKAGE = ROOT / 'output/builds/TexasPub.zip'
GUIDE = ROOT / 'docs/3d-production/macos-preview-readme.md'


def main():
    with zipfile.ZipFile(PACKAGE) as original:
        entries = [(info, original.read(info)) for info in original.infolist()
                   if info.filename not in ('README.md', 'build-manifest.json')]
    executable = 'Godot德扑酒馆.app/Contents/MacOS/Godot德扑酒馆'
    if not any(info.filename == executable for info, _ in entries):
        raise RuntimeError('Expected player application is missing')
    guide = GUIDE.read_bytes()
    files = {info.filename: {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
             for info, data in entries if not info.is_dir()}
    files['README.md'] = {'bytes': len(guide), 'sha256': hashlib.sha256(guide).hexdigest()}
    manifest = json.dumps({'platform': 'macOS', 'test_harness': False,
                           'clean_machine_verified': False, 'files': files},
                          ensure_ascii=False, indent=2).encode() + b'\n'
    handle, temporary = tempfile.mkstemp(dir=PACKAGE.parent, suffix='.zip')
    os.close(handle)
    try:
        with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as output:
            for info, data in entries:
                output.writestr(info, data)
            output.writestr('README.md', guide)
            output.writestr('build-manifest.json', manifest)
        with zipfile.ZipFile(temporary) as result:
            assert result.read('README.md') == guide
            for info, data in entries:
                assert result.read(info.filename) == data
                assert result.getinfo(info.filename).external_attr == info.external_attr
            assert result.testzip() is None
        os.replace(temporary, PACKAGE)
    finally:
        Path(temporary).unlink(missing_ok=True)
    print('Mac guide and manifest packaged; application bytes and permissions preserved')


if __name__ == '__main__':
    main()
