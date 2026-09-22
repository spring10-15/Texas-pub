#!/bin/zsh
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
printf '输入试玩编号（1–2147483646，直接回车使用 20260922）：'
IFS= read -r trial_seed
trial_seed="${trial_seed:-20260922}"
if [[ "$trial_seed" != <-> ]] || (( trial_seed < 1 || trial_seed > 2147483646 )); then
  printf '编号无效，请重新启动并输入范围内的整数。\n'
  exit 1
fi
exec /Applications/Godot.app/Contents/MacOS/Godot --path "$project_dir" --scene res://three_d/scenes/main.tscn -- "--playtest-seed=$trial_seed"
