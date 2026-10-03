"""Build an isolated Mac release-template soak harness, not a player release."""
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from build_preview import ENGINE, PROJECT, OUTPUT, sources, fingerprint


def main():
    before = fingerprint()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="texaspub-native-soak-") as temporary:
        project = Path(temporary)
        shutil.copyfile(PROJECT / "icon.svg", project / "icon.svg")
        for source in sources():
            target = project / source.relative_to(PROJECT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        script = Path(__file__).with_name("soak_preview.gd").read_text()
        (project / "soak_main.gd").write_text(script.replace("extends SceneTree", "extends Node", 1).replace("func _initialize()", "func _ready()").replace("root.add_child(world)", "get_tree().root.add_child(world)").replace("await physics_frame", "await get_tree().physics_frame").replace("await process_frame", "await get_tree().process_frame").replace("quit(", "get_tree().quit("))
        (project / "soak_main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://soak_main.gd" id="1"]\n[node name="NativeSoak" type="Node"]\nscript = ExtResource("1")\n')
        config = (project / "project.godot").read_text()
        config = re.sub(r'^run/main_scene=.*$', 'run/main_scene="res://soak_main.tscn"', config, flags=re.MULTILINE)
        (project / "project.godot").write_text(config)
        preset = (PROJECT / "export_presets.cfg").read_text().split('[preset.1]')[0]
        preset = re.sub(r'^export_filter=.*$', 'export_filter="all_resources"', preset, flags=re.MULTILINE)
        (project / "export_presets.cfg").write_text(preset)
        for label, args in [("import", ["--editor", "--import"]),
                            ("export", ["--export-release", "macOS Preview", str(OUTPUT / "TexasPub-native-soak.zip")])]:
            result = subprocess.run([str(ENGINE), "--headless", "--path", temporary, *args], capture_output=True, text=True, timeout=300)
            log = result.stdout + result.stderr
            (OUTPUT / ("native-soak-" + label + ".log")).write_text(log)
            if result.returncode or "ERROR:" in log:
                raise RuntimeError(f"Native soak {label} failed; inspect log")
            print(label + " passed", flush=True)
    if fingerprint() != before:
        raise RuntimeError("Runtime sources changed during test build")
    (OUTPUT / "native-soak-build.json").write_text(json.dumps({"runtime_sha256": before, "test_harness": True, "player_release": False}, indent=2) + "\n")


if __name__ == "__main__":
    main()
