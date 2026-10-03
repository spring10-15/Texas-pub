"""Summarize raw soak samples without turning partial evidence into a pass."""
import argparse
import hashlib
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "output/builds/soak-30min.json"
DESTINATION = ROOT / "output/builds/soak-analysis.json"
PHASES = ["cargo", "ledger", "mirror", "embers", "lift", "kitchen", "quay", "stash"]


def summarize(report):
    elapsed = float(report.get("elapsed_seconds", 0))
    target = int(report["duration_target_seconds"])
    complete = report.get("status") == "completed" and elapsed >= target and report.get("failures") == 0
    groups = {}
    for sample in report.get("samples", []):
        step = int(sample["tour_step"])
        key = ((step // 8) % 4, step % 8)
        groups.setdefault(key, []).append(sample)
    results = []
    for (venue, phase), samples in sorted(groups.items()):
        first, last = samples[0], samples[-1]
        results.append({
            "venue_index": venue, "phase": PHASES[phase], "sample_count": len(samples),
            "first_second": first["elapsed_seconds"], "last_second": last["elapsed_seconds"],
            "median_of_window_medians_ms": statistics.median(s["median_callback_ms"] for s in samples),
            "worst_window_p95_ms": max(s["p95_callback_ms"] for s in samples),
            "static_memory_first_bytes": first["static_memory_bytes"],
            "static_memory_last_bytes": last["static_memory_bytes"],
            "static_memory_delta_bytes": last["static_memory_bytes"] - first["static_memory_bytes"],
            "video_memory_delta_bytes": last["video_memory_bytes"] - first["video_memory_bytes"],
            "node_count_delta": last["nodes"] - first["nodes"],
            "spans_multiple_tours": int(first["tour_step"]) != int(last["tour_step"]),
        })
    return {
        "raw_status": report.get("status"), "elapsed_seconds": elapsed,
        "duration_target_seconds": target, "complete_duration_and_checks": complete,
        "qualifies_as_30min_sample": complete and target >= 1800,
        "target_hardware_60fps_verified": False, "memory_leak_absence_verified": False,
        "groups": results,
        "scope": "Same-venue and same-phase aggregate samples. Callback pacing is not GPU time; static memory is not process RSS. Completion still needs process exit/log inspection, and no automatic performance gate is claimed.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--output", type=Path, default=DESTINATION)
    args = parser.parse_args()
    raw = args.source.read_bytes()
    analysis = summarize(json.loads(raw))
    analysis["source_sha256"] = hashlib.sha256(raw).hexdigest()
    analysis["source_path"] = str(args.source.resolve())
    args.output.write_text(json.dumps(analysis, indent=2) + "\n")
    print(json.dumps({k: analysis[k] for k in (
        "raw_status", "elapsed_seconds", "complete_duration_and_checks", "qualifies_as_30min_sample")}))


if __name__ == "__main__":
    main()
