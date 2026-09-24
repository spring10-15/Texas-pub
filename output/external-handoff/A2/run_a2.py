#!/usr/bin/env python3
"""A2 串行运行器：逐脚本硬超时 + 进程组 SIGKILL + 原始日志留档。

与 A 轮同款机制，继续复用：
  - 每个脚本单独一个 .log，含命令、耗时、退出码、stdout、stderr
  - 超时杀整个进程组（只 kill(pid) 会留下子进程）
  - 同时扫描日志里的 SCRIPT ERROR，不只看退出码
"""
import os
import re
import signal
import subprocess
import sys
import time

ROOT = "/Users/springwater/Desktop/Claude/项目集群/Gen 项目集群/1、德扑酒馆：落袋为安"
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
LOGDIR = os.path.join(ROOT, "output/external-handoff/A2/logs")
REPRO = os.path.join(ROOT, "docs/3d-production/external-handoff/A2-boundaries/repro")

TIMEOUT = 240

# (日志名, 脚本绝对路径, 额外用户参数)
SUITES = [
    ("spatial_interaction_test", os.path.join(ROOT, "Godot/three_d/tests/spatial_interaction_test.gd"), ["--test"]),
    ("two_tables", os.path.join(ROOT, "Godot/three_d/tests/two_tables.gd"), ["--test"]),
    ("dealer_rotation_test", os.path.join(ROOT, "Godot/three_d/tests/dealer_rotation_test.gd"), ["--test"]),
    ("run_restore_bounds_test", os.path.join(ROOT, "Godot/three_d/tests/run_restore_bounds_test.gd"), ["--test"]),
    ("diag_dealer_rotation", os.path.join(REPRO, "diag_dealer_rotation.gd"), ["--test"]),
    ("diag_first_discount", os.path.join(REPRO, "diag_first_discount.gd"), ["--test"]),
    ("diag_save_recovery", os.path.join(REPRO, "diag_save_recovery.gd"), ["--test"]),
]

ERROR_PATTERN = re.compile(r"^(SCRIPT ERROR|USER SCRIPT ERROR|Parse Error|ERROR|USER ERROR)", re.M)


def run_one(name, script, extra):
    argv = [GODOT, "--headless", "--path", "Godot", "--script", script, "--"] + extra
    started = time.time()
    proc = subprocess.Popen(
        argv, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        text=True, start_new_session=True,
    )
    timed_out = False
    try:
        out, err = proc.communicate(timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        timed_out = True
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except ProcessLookupError:
            pass
        out, err = proc.communicate(timeout=20)
    elapsed = time.time() - started

    errors = ERROR_PATTERN.findall(out + "\n" + err)
    log_path = os.path.join(LOGDIR, name + ".log")
    with open(log_path, "w") as handle:
        handle.write("CMD: " + " ".join(argv) + "\n")
        handle.write("DURATION: %.2fs\n" % elapsed)
        handle.write("EXIT: %s\n" % ("TIMEOUT" if timed_out else proc.returncode))
        handle.write("ERROR_LINES: %d\n" % len(errors))
        handle.write("--- STDOUT ---\n" + out + "\n--- STDERR ---\n" + err + "\n")

    status = "TIMEOUT" if timed_out else ("ERROR" if errors else ("OK" if proc.returncode == 0 else "FAIL"))
    print("%-28s %-8s exit=%s %.1fs errors=%d" % (name, status, proc.returncode, elapsed, len(errors)))
    return {"name": name, "status": status, "exit": proc.returncode, "secs": elapsed, "errors": len(errors), "log": log_path}


def main():
    os.makedirs(LOGDIR, exist_ok=True)
    only = sys.argv[1] if len(sys.argv) > 1 else ""
    results = []
    for name, script, extra in SUITES:
        if only and only not in name:
            continue
        if not os.path.exists(script):
            print("%-28s MISSING %s" % (name, script))
            continue
        results.append(run_one(name, script, extra))
    print("\n合计 %d 项；ERROR %d 项；TIMEOUT %d 项" % (
        len(results),
        sum(1 for r in results if r["status"] == "ERROR"),
        sum(1 for r in results if r["status"] == "TIMEOUT"),
    ))


if __name__ == "__main__":
    main()
