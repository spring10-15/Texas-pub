"""Audit the three current character samples directly from exported GLB bytes.

Run from any directory with Python 3. No Blender, Godot or third-party packages.
This checks export integrity, not realism, pose contact or performance.
"""
import hashlib
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'Godot/three_d/assets/characters'
IDS = ('bartender', 'ledger-clerk', 'dock-braggart')


def read_glb(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert (magic, version, length) == (0x46546C67, 2, len(raw)), 'Invalid GLB header'
    chunks = {}
    offset = 12
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        assert offset + size <= len(raw), 'Truncated GLB chunk'
        chunks[kind] = raw[offset:offset + size]
        offset += size
    return raw, json.loads(chunks[0x4E4F534A]), chunks[0x004E4942]


def accessor(doc, binary, index):
    a = doc['accessors'][index]
    assert 'sparse' not in a, 'Sparse accessor requires a separate audit'
    view = doc['bufferViews'][a['bufferView']]
    assert view.get('buffer', 0) == 0, 'External buffer requires a separate audit'
    formats = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}
    width = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[a['type']]
    fmt = '<' + formats[a['componentType']] * width
    size = struct.calcsize(fmt)
    stride = view.get('byteStride', size)
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    assert start + (a['count'] - 1) * stride + size <= view.get('byteOffset', 0) + view['byteLength'], 'Accessor exceeds buffer view'
    for i in range(a['count']):
        values = struct.unpack_from(fmt, binary, start + i * stride)
        if a.get('normalized', False) and a['componentType'] != 5126:
            scale = {5121: 255, 5123: 65535, 5125: 4294967295}[a['componentType']]
            values = tuple(v / scale for v in values)
        yield values


def audit():
    manifest = json.loads((ASSETS / 'manifest.json').read_text())
    export = json.loads((ROOT / 'assets/blender/characters/high-fidelity/export-report.json').read_text())
    report = {'scope': 'Three sample GLBs; export integrity only. Not final art or performance acceptance.', 'characters': {}, 'failures': []}
    for character in IDS:
        try:
            raw, doc, binary = read_glb(ASSETS / (character + '.glb'))
            entry = manifest[character]
            assert entry == export[character], 'Runtime and source export manifests differ'
            assert len(raw) == entry['bytes'], 'Byte size differs from manifest'
            assert len(doc['skins']) == 1, 'Expected one skin'
            joints = doc['skins'][0]['joints']
            assert len(joints) == entry['bones'], 'Bone count differs from manifest'
            names = {doc['nodes'][j]['name'] for j in joints}
            assert {'head', 'hand.R', 'finger0.R', 'thumb_tip.L'} <= names, 'Required bones missing'
            clips = {a['name'] for a in doc['animations']}
            assert set(entry['clips']) <= clips, 'Required animation missing'
            assert (ROOT / entry['source']).is_file(), 'Editable source missing'
            triangles = weighted = 0
            max_error = 0.0
            for mesh in doc['meshes']:
                for primitive in mesh['primitives']:
                    assert primitive.get('mode', 4) == 4, 'Expected triangles'
                    attributes = primitive['attributes']
                    count = doc['accessors'][attributes['POSITION']]['count']
                    indices = list(accessor(doc, binary, primitive['indices']))
                    assert len(indices) % 3 == 0, 'Incomplete triangle'
                    assert all(0 <= v[0] < count for v in indices), 'Index exceeds vertices'
                    triangles += len(indices) // 3
                    weights = list(accessor(doc, binary, attributes['WEIGHTS_0']))
                    bindings = list(accessor(doc, binary, attributes['JOINTS_0']))
                    assert len(weights) == len(bindings) == count, 'Skin accessor count mismatch'
                    assert 'WEIGHTS_1' not in attributes, 'Additional influences require a separate audit'
                    for row, bone_row in zip(weights, bindings):
                        assert all(math.isfinite(v) and 0 <= v <= 1 for v in row), 'Invalid skin weight'
                        assert all(0 <= v < len(joints) for v in bone_row), 'Invalid joint index'
                        error = abs(sum(row) - 1)
                        assert error < 1e-5, 'Skin weights do not sum to one'
                        max_error = max(max_error, error)
                    weighted += count
            assert triangles == entry['triangles'], 'Triangle count differs from manifest'
            report['characters'][character] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw), 'triangles': triangles, 'bones': len(joints), 'clips': sorted(clips), 'weighted_export_vertices': weighted, 'max_weight_sum_error': max_error}
        except (AssertionError, KeyError, ValueError, OSError, struct.error) as error:
            report['failures'].append(character + ': ' + str(error))
    report['passed'] = not report['failures']
    output = ROOT / 'output/3d/characters-handoff-audit.json'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(audit())
