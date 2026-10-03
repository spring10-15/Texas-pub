"""Observe one native soak process; RSS samples start when this observer starts."""
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
REPORT = ROOT / "output/builds/native-soak-30min.json"
OUTPUT = ROOT / "output/builds/native-soak-rss.json"


def main():
    report = json.loads(REPORT.read_text())
    pid = int(report["process_id"])
    executable = report["executable_path"]
    result = {"pid": pid, "executable": executable, "status": "observing", "samples": [],
              "scope": "Process RSS in bytes from macOS ps; partial observation, not GPU memory or proof of leak absence."}
    while True:
        process = subprocess.run(["ps", "-p", str(pid), "-o", "rss=", "-o", "command="], capture_output=True, text=True)
        line = process.stdout.strip()
        if process.returncode or not line:
            result["status"] = "process_ended"
            break
        rss, command = line.split(None, 1)
        if executable not in command:
            result["status"] = "process_identity_changed"
            break
        try:
            report = json.loads(REPORT.read_text())
        except json.JSONDecodeError:
            time.sleep(1)
            continue
        if int(report["process_id"]) != pid:
            result["status"] = "report_identity_changed"
            break
        result["samples"].append({"wall_time_unix": time.time(), "report_elapsed_seconds": report.get("elapsed_seconds"), "rss_bytes": int(rss) * 1024})
        OUTPUT.write_text(json.dumps(result, indent=2) + "\n")
        if report["status"] != "running":
            result["status"] = "report_terminal"
            break
        time.sleep(10)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n")
    print(result["status"], len(result["samples"]), "RSS samples")


if __name__ == "__main__":
    main()
