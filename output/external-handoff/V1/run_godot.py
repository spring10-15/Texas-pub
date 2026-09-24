#!/usr/bin/env python3
"""按任务书要求跑一次 Godot，带**墙钟超时 + 杀整个进程组**，原始输出落日志文件。

为什么需要它：套件/探针一旦中途抛 `SCRIPT ERROR`，末行 `quit()` 永不执行，进程会永久挂住；
macOS 又没有 `timeout(1)`。所以统一用本脚本执行，并把 stdout/stderr 原样落盘（不接管道，
管道会缓冲，一挂住就一行都拿不到）。

**用法（`--` 之后的参数原样传给 Godot，不做任何改写）：**

  python3 run_godot.py --log <日志路径> [--timeout 180] [--windowed] \\
        -- --script res://... -- --test

  --windowed  不加 --headless（用于需要真实渲染帧的截图任务；headless 下 save_png 必超时）

注意：用户参数分隔符 `--` **必须原样保留**，否则 `--test` 会被 Godot 当成它自己的单元测试
开关并直接 abort（本机 Godot 编译时未开 `tests=yes`）。
"""
import os
import pathlib
import signal
import subprocess
import sys
import time

GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'


def main() -> int:
    argv_in = sys.argv[1:]
    if '--' not in argv_in:
        print('用法：run_godot.py --log <log> [--timeout N] [--windowed] -- <Godot 参数...>')
        return 2
    cut = argv_in.index('--')
    opts, godot_args = argv_in[:cut], argv_in[cut + 1:]

    log = timeout = None
    windowed = False
    project_path = None
    i = 0
    while i < len(opts):
        o = opts[i]
        if o == '--log':
            log = pathlib.Path(opts[i + 1]); i += 2
        elif o == '--timeout':
            timeout = float(opts[i + 1]); i += 2
        elif o == '--path':
            project_path = opts[i + 1]; i += 2
        elif o == '--windowed':
            windowed = True; i += 1
        else:
            print(f'未知选项：{o}'); return 2
    if log is None or timeout is None:
        print('缺少 --log / --timeout'); return 2

    root = pathlib.Path(__file__).resolve().parents[3]
    argv = [GODOT, '--path', project_path or str(root / 'Godot')]
    if not windowed:
        argv.append('--headless')
    argv += godot_args

    log.parent.mkdir(parents=True, exist_ok=True)
    started = time.strftime('%Y-%m-%d %H:%M:%S')
    t0 = time.time()
    proc = subprocess.Popen(argv, cwd=str(root), stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, start_new_session=True)
    status = None
    try:
        out, _ = proc.communicate(timeout=timeout)
        code = proc.returncode
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)      # 只 kill(pid) 不够
        out, _ = proc.communicate(timeout=20)
        code = None
        status = 'TIMEOUT'
    elapsed = round(time.time() - t0, 1)

    header = (f"# {log.name}\n# cmd: {' '.join(argv)}\n# started: {started}\n"
              f"# elapsed_s: {elapsed}\n# exit_code: {code}\n\n")
    log.write_text(header + '--- stdout+stderr ---\n' + (out or ''), encoding='utf-8')
    print(f"[run_godot] exit={code} elapsed={elapsed}s status={status or 'ok'}")
    print(f"[run_godot] log: {log}")
    return 1 if (code != 0 or status) else 0


if __name__ == '__main__':
    sys.exit(main())
