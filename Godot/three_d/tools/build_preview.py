"""Export and verify the current resource pack; this does not create a native app."""
import hashlib
import json
import re
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PROJECT = ROOT / "Godot"
ENGINE = Path("/Applications/Godot.app/Contents/MacOS/Godot")
OUTPUT = ROOT / "output/builds"
PACK = OUTPUT / "TexasPub-preview.pck"
EXTENSIONS = {".gd", ".tscn", ".tres", ".res", ".glb", ".png", ".jpg", ".jpeg",
              ".webp", ".svg", ".ogg", ".wav", ".mp3", ".ogv", ".ttf", ".otf"}


def sources():
    return sorted(p for folder in ("assets", "scenes", "scripts", "rules")
                  for p in (PROJECT / "three_d" / folder).rglob("*")
                  if p.is_file() and (p.suffix in EXTENSIONS or p.suffix == ".json")) + [PROJECT / "project.godot"]


def fingerprint():
    digest = hashlib.sha256()
    for path in sources():
        digest.update(path.relative_to(ROOT).as_posix().encode())
        digest.update(hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()


def execute(label, arguments, directory):
    result = subprocess.run([str(ENGINE), *arguments], cwd=directory,
                            capture_output=True, text=True, timeout=300)
    log = result.stdout + result.stderr
    (OUTPUT / (label + ".log")).write_text(log)
    if result.returncode or any(marker in log for marker in ("ERROR:", "SCRIPT ERROR:", "Parse Error:")):
        raise RuntimeError(f"{label} failed; see {OUTPUT / (label + '.log')}")
    print(label + ": PASS", flush=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report_path = OUTPUT / "preview-build.json"
    report = {"status": "running", "started_utc": datetime.now(timezone.utc).isoformat(),
              "native_application": False}
    report_path.write_text(json.dumps(report, indent=2))
    try:
        paths = ["res://" + p.relative_to(PROJECT).as_posix()
                 for p in sources() if p.suffix in EXTENSIONS]
        preset = PROJECT / "export_presets.cfg"
        updated, replacements = re.subn(r"^export_files=.*$",
            lambda _: "export_files=PackedStringArray(" + ", ".join(json.dumps(p) for p in paths) + ")",
            preset.read_text(), flags=re.MULTILINE)
        if replacements != 1:
            raise RuntimeError("Expected one resource selection in export_presets.cfg")
        preset.write_text(updated)
        before = fingerprint()
        execute("preview-export", ["--headless", "--path", str(PROJECT),
                "--export-pack", "macOS Preview", str(PACK)], ROOT)
        with tempfile.TemporaryDirectory(prefix="texaspub-pack-build-") as temporary:
            base = ["--headless", "--path", temporary, "--main-pack", str(PACK)]
            for name in ("pack", "loop"):
                execute("preview-" + name, base + ["--script", str(Path(__file__).with_name(
                    "verify_export_" + name + ".gd")), "--", "--test"], temporary)
            for scenario in ("stash", "table"):
                save = str(Path(temporary) / ("texaspub-restart-" + scenario + ".save"))
                for phase in ("write", "read"):
                    execute("preview-restart-" + scenario + "-" + phase,
                        base + ["--script", str(Path(__file__).with_name("verify_export_restart.gd")),
                                "--", "--test", phase, scenario, save], temporary)
        if fingerprint() != before:
            raise RuntimeError("Runtime sources changed during build; rebuild after edits finish")
        report.update(status="passed", runtime_sha256=before, resource_count=len(paths),
                      pack_bytes=PACK.stat().st_size,
                      pack_sha256=hashlib.sha256(PACK.read_bytes()).hexdigest())
    except Exception as error:
        report.update(status="failed", error=str(error))
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
