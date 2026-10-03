#!/usr/bin/env python3
"""Build a current-tree overlay while preserving the frozen A8 audit files."""
from __future__ import annotations

import csv
import difflib
import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
AUDIT = ROOT / "docs/3d-production/external-handoff/A8-global-catalog-audit"
CATALOG = ROOT / "docs/3d-production/phase-1/coverage/transitions.json"
SOURCE_SWEEP = ROOT / "output/external-handoff/A8/source-function-sweep.json"
SOURCE_BASELINE = "29dbc411d13b5baca8f22a28465c8971bab182a1"
LATEST_REPORT = "output/3d/regression/" + sorted((ROOT / "output/3d/regression").glob("*/report.json"))[-1].parent.name + "/report.json"


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line_map(relative: str) -> dict[int, int]:
    """Map frozen A8 source line references to the current file after insertions."""
    old_text = subprocess.check_output(
        ["git", "show", f"{SOURCE_BASELINE}:{relative}"], cwd=ROOT, text=True
    )
    new_text = (ROOT / relative).read_text(encoding="utf-8")
    old_lines, new_lines = old_text.splitlines(), new_text.splitlines()
    mapping: dict[int, int] = {}
    for tag, old_start, old_end, new_start, new_end in difflib.SequenceMatcher(
        a=old_lines, b=new_lines, autojunk=False
    ).get_opcodes():
        if tag == "equal":
            for offset in range(old_end - old_start):
                mapping[old_start + offset + 1] = new_start + offset + 1
        elif tag == "replace":
            old_size, new_size = old_end - old_start, new_end - new_start
            for offset in range(old_size):
                if new_size:
                    mapped_offset = min(offset, new_size - 1)
                    mapping[old_start + offset + 1] = new_start + mapped_offset + 1
    return mapping


def remap_source_refs(row: dict[str, str], maps: dict[str, dict[int, int]]) -> None:
    source = row["source_file"]
    if source not in maps:
        return
    mapping = maps[source]

    def replace_ref(match: re.Match[str]) -> str:
        reference_source = match.group(1)
        reference_map = maps.get(reference_source)
        if reference_map is None:
            return match.group(0)
        start = int(match.group(2))
        end = int(match.group(3) or start)
        if start not in reference_map or end not in reference_map:
            raise ValueError(f"Cannot remap frozen source reference: {match.group(0)}")
        mapped_start, mapped_end = reference_map[start], reference_map[end]
        suffix = f"-{mapped_end}" if match.group(3) else ""
        return f"{match.group(1)}:{mapped_start}{suffix}"

    row["source_line"] = re.sub(
        r"([A-Za-z0-9_./-]+\.gd):(\d+)(?:-(\d+))?", replace_ref, row["source_line"]
    )
    function_line = row["function_line"]
    if function_line.isdigit():
        old_line = int(function_line)
        if old_line not in mapping:
            raise ValueError(f"Cannot remap function line {source}:{old_line}")
        row["function_line"] = str(mapping[old_line])


def main() -> int:
    source_sweep = json.loads(SOURCE_SWEEP.read_text(encoding="utf-8"))
    if source_sweep.get("branch_inventory_sha256") != sha256(AUDIT / "current-tree-branch-inventory.csv"):
        raise SystemExit("A8 source-function sweep is stale; rebuild it after the current-tree overlay")
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    catalog_ids = {row["id"] for row in catalog["transitions"]}
    retired_ids = {row["id"]: row["merged_into"] for row in catalog.get("retired_transition_ids", [])}
    branch_fields, branches = read_csv(AUDIT / "branch-inventory.csv")
    _, old_gaps = read_csv(AUDIT / "unmapped-reachable.csv")

    rng_control_rows = 0
    for row in branches:
        if row["catalog_id"] == "persistence_replay.rng_negative_control":
            row.update({
                "catalog_id": "-",
                "outcome": "not_a_transition",
                "evidence_report": "output/3d/persistence-replay-coverage.json",
                "evidence_strength": "none",
                "disposition": "unreachable_or_not_transition",
                "notes": "从状态转移目录移出：该条只在测试中人工改写 table.rng.value 并检查负对照发散，不是游戏源码产生的 accepted/rejected 状态结果。现以 transitions.json 的 verification_controls 独立跟踪，负对照仍须通过但不计入转移分母。",
            })
            rng_control_rows += 1
    if rng_control_rows != 1:
        raise SystemExit(f"Unexpected RNG verification-control rows: {rng_control_rows}")

    merged_route_cash_rows = 0
    for row in branches:
        if (row["catalog_id"] == "route_guard.cash_general"
                or row["catalog_id"] in retired_ids and row["catalog_id"].startswith("route_guard.cash_")):
            row["catalog_id"] = retired_ids.get(row["catalog_id"], row["catalog_id"])
            row["test"] = "Godot/three_d/tests/route_guard_coverage_test.gd::cash_insufficient across six routes"
            row["evidence_report"] = "output/3d/route-guard-coverage.json"
            row["evidence_strength"] = "strong"
            row["disposition"] = "catalogued_strong"
            row["notes"] += " 当前目录将路线名/费用差异作为同一 cash<fee 拒绝结果的输入变体；专项仍逐酒馆、逐预约与六路线运行全部样本，但只登记 route_guard.cash_general 一个状态结果。"
            merged_route_cash_rows += 1
    if merged_route_cash_rows != 6:
        raise SystemExit(f"Unexpected merged route cash rows: {merged_route_cash_rows}")

    duplicate_rejection_merges = {
        "service.cool_used": "service.cool_unavailable",
        "service.cool_unneeded": "service.cool_unavailable",
        "search.cool_used": "search.cool_unavailable",
        "search.cool_unneeded": "search.cool_unavailable",
        "search.inactive": "search.phase_unavailable",
        "search.table_active": "search.phase_unavailable",
        "service.intel_known": "service.intel_unavailable",
        "service.intel_unknown": "service.intel_unavailable",
        "route_guard.stairs_unknown": "route_guard.special_unknown",
        "route_guard.river_unknown": "route_guard.special_unknown",
        "route_guard.stairs_heat": "route_guard.special_heat",
        "route_guard.river_heat": "route_guard.special_heat",
    }
    merged_rejection_rows = 0
    for row in branches:
        old_id = row["catalog_id"]
        if old_id not in duplicate_rejection_merges:
            continue
        prefix = old_id.split(".", 1)[0]
        row["catalog_id"] = duplicate_rejection_merges[old_id]
        input_cases = {
            "service.cool_used": "cool_used and cool_unneeded",
            "service.cool_unneeded": "cool_used and cool_unneeded",
            "search.cool_used": "cool_used and cool_unneeded",
            "search.cool_unneeded": "cool_used and cool_unneeded",
            "search.inactive": "inactive and table_active",
            "search.table_active": "inactive and table_active",
            "service.intel_known": "intel_known and intel_unknown",
            "service.intel_unknown": "intel_known and intel_unknown",
            "route_guard.stairs_unknown": "stairs_unknown and river_unknown",
            "route_guard.river_unknown": "stairs_unknown and river_unknown",
            "route_guard.stairs_heat": "stairs_heat and river_heat",
            "route_guard.river_heat": "stairs_heat and river_heat",
        }
        row["test"] = f"Godot/three_d/tests/{prefix}_coverage_test.gd::{input_cases[old_id]} input cases"
        report_prefix = "route-guard" if prefix == "route_guard" else prefix
        row["evidence_report"] = f"output/3d/{report_prefix}-coverage.json"
        row["evidence_strength"] = "strong"
        row["disposition"] = "catalogued_strong"
        row["notes"] += " 当前目录按动作入口将同一 guard 的多个拒绝条件归为一个结果 ID；专项仍分别执行各输入并断言完整 checkpoint 不变。"
        merged_rejection_rows += 1
    expected_rejection_rows = 16  # SearchEvents guards are recorded at both Run dispatch and their source; route guards have two input variants per shared outcome.
    if merged_rejection_rows != expected_rejection_rows:
        raise SystemExit(f"Unexpected merged rejection rows: {merged_rejection_rows}/{expected_rejection_rows}")

    boundary_input_merges = {
        "route_guard.fixed_expiry_boundary": "extract.fixed",
        "route_guard.stairs_heat_boundary": "extract.service-stairs",
        "route_guard.river_heat_boundary": "extract.river-launch",
    }
    merged_boundary_rows = 0
    for row in branches:
        old_id = row["catalog_id"]
        if old_id not in boundary_input_merges:
            continue
        if retired_ids.get(old_id) != boundary_input_merges[old_id]:
            raise SystemExit(f"Route boundary retirement disagrees with catalog: {old_id}")
        row["catalog_id"] = boundary_input_merges[old_id]
        row["test"] = "Godot/three_d/tests/route_guard_coverage_test.gd::" + old_id.split(".", 1)[1]
        row["evidence_report"] = "output/3d/route-guard-coverage.json"
        row["notes"] += " 此处是已接受撤离的边界输入，费用与最终状态复用对应 extract.* 结果；专项继续核对等号边界，但不另计状态结果。"
        merged_boundary_rows += 1
    if merged_boundary_rows != 3:
        raise SystemExit(f"Unexpected merged route boundary rows: {merged_boundary_rows}")

    partial_bankroll = 0
    entry_heat_cap = 0
    settlement_heat_relief = 0
    player_raise_pattern = 0
    room_layout_selected = 0
    room_layout_locked = 0
    poker_short_blinds = 0
    poker_seeded_deals = 0
    poker_open_raise_right = 0
    player_pause_input = 0
    player_interaction_signal = 0
    world_search_evidence = 0
    world_product_evidence = 0
    reclassified_nonplayer = 0
    presentation_only = 0
    focus_idempotence = 0
    world_autosave = 0
    world_focus_out = 0
    world_close_request = 0
    player_look = 0
    player_movement = 0
    player_unfocused_input = 0
    reclassified_weak = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/run.gd"
                and row["source_line"] == "Godot/three_d/rules/run.gd:61-62"
                and "bankroll 取 min" in row["branch_or_guard"]):
            row.update({
                "catalog_id": "start.partial_bankroll",
                "test": "Godot/three_d/tests/lifecycle_coverage_test.gd::start.partial_bankroll",
                "evidence_report": f"output/3d/lifecycle-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "当前目录已登记 start.partial_bankroll；vault=120 的正式测试验证 vault=0、cash/bankroll=120、财富守恒、Run active 及 revision 增加。",
            })
            partial_bankroll += 1
        if row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:175" and "entryHeatBonus" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "entry.heat_cap",
                "test": "Godot/three_d/tests/entry_coverage_test.gd::entry.heat_cap",
                "evidence_report": f"output/3d/entry-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "rooftop-club 入场加成为 1；从风声 5 通过公开 enter_table 成功入座后验证风声封顶 6、现金支付、vault 不变、revision 前进且实际桌型正确。",
            })
            entry_heat_cap += 1
        if row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:205" and "winHeatRelief" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "settlement.heat_relief",
                "test": "Godot/three_d/tests/settlement_coverage_test.gd::settlement.heat_relief",
                "evidence_report": f"output/3d/settlement-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "盈利结算余烬桌时，测试验证 cash 回收、桌面清理、完成标记与 revision 前进，并精确断言 heat 按 winHeatRelief 从 2 降至 1。",
            })
            settlement_heat_relief += 1
        if row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:119-120" and "playerPattern.raiseCount" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "poker.player_raise_pattern",
                "test": "Godot/three_d/tests/poker_action_coverage_test.gd::poker.player_raise_pattern",
                "evidence_report": f"output/3d/poker_action-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "入口测试分别执行玩家 raise、玩家 all-in 与对手 raise；玩家两种侵略动作将 playerPattern.raiseCount 加一，而对手动作保持为零，验证画像只统计玩家行为。",
            })
            player_raise_pattern += 1
        if row["source_file"] == "Godot/three_d/rules/run_variants.gd" and row["source_line"] == "Godot/three_d/rules/run_variants.gd:36" and "room_layout" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "run_variant.room_layout_selected",
                "test": "Godot/three_d/tests/run_variant_coverage_test.gd::run_variant.room_layout_selected",
                "evidence_report": f"output/3d/run-variant-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "正式 Run.start 对四家酒馆均提交 linear/fork 计划；测试验证两图解锁拓扑不同且 checkpoint 恢复后保持一致。",
            })
            room_layout_selected += 1
        if row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] in {"Godot/three_d/rules/run.gd:147-148", "Godot/three_d/rules/run.gd:149"} and "房间图" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "entry.locked",
                "test": "Godot/three_d/tests/run_variant_coverage_test.gd::entry.locked;Godot/three_d/tests/entry_coverage_test.gd::entry.locked",
                "evidence_report": f"output/3d/run-variant-coverage.json;output/3d/entry-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "两种房间图分别在镜厅/余烬桌条件未满足时调用公开 enter_table；完整 Run checkpoint 前后相同，确认 entry.locked 拒绝不扣款、不增风声、不消耗抵押物且 revision 不变。",
            })
            room_layout_locked += 1
        if row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:44-46" and "盲注封顶" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "poker_blind.short_stack_posts",
                "test": "Godot/three_d/tests/poker_blind_coverage_test.gd::poker_blind.short_stack_posts",
                "evidence_report": f"output/3d/poker-blind-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "全部四桌均以短于小盲/大盲的筹码进入下一手；精确断言实际封顶金额、两名短筹码仍获底牌且未弃牌、行动位、revision 与整桌财富守恒。",
            })
            poker_short_blinds += 1
        if row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:47-50" and "洗牌并两轮各发一张底牌" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "poker_progress.seeded_deal",
                "test": "Godot/three_d/tests/poker_progress_coverage_test.gd::poker_progress.seeded_deal",
                "evidence_report": f"output/3d/poker_progress-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "四桌都使用固定种子独立重算完整洗牌；逐座断言两轮私牌、余下牌堆、RNG 最终态与初始 revision，确认相同种子得到可重放的起手牌分发。",
            })
            poker_seeded_deals += 1
        if row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:102-102" and "开注（old_target==0）" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "poker_action.open",
                "test": "Godot/three_d/tests/poker_action_coverage_test.gd::poker_action.open",
                "evidence_report": f"output/3d/poker_action-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "四桌均测试翻牌后首次开注；除核对投入、底池和下注额外，断言 raiseUsed 仍为 false 且下一行动者仍有合法 raise 选项，证明开注后未错误关闭本街加注权。",
            })
            poker_open_raise_right += 1
        if row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:38-42" and "pause_requested.emit()" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "world.pause",
                "test": "Godot/three_d/tests/world_coverage_test.gd::world.pause",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "物理 Esc KeyEvent 进入 Player._unhandled_input，经 pause_requested 信号实际调用 World.toggle_pause/pause_game；测试断言 paused、暂停面板显示且玩家控制禁用。",
            })
            player_pause_input += 1
        if row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:45-47" and "camera.rotation.x" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "player.look_changed",
                "test": "Godot/three_d/tests/player_input_coverage_test.gd::player.look_changed",
                "evidence_report": f"output/3d/player-input-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "桌面 Godot 进程以 captured 鼠标模式投递真实 InputEventMouseMotion；断言玩家 yaw 更新、camera pitch 达到 ±LOOK_PITCH_LIMIT 且完整 checkpoint 的 look/player 字段改变。",
            })
            player_look += 1
        if row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:56-60" and "move_and_slide()" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "player.movement",
                "test": "Godot/three_d/tests/player_input_coverage_test.gd::player.movement",
                "evidence_report": f"output/3d/player-input-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "正式物理输入按住 move_forward；断言 player checkpoint 发生可见位移且未穿过藏匿点外墙，将连续位置变化按一个移动语义结果计数。",
            })
            player_movement += 1
        if row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:50-51" and "focused 无效" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "world.raycast_unfocused",
                "test": "Godot/three_d/tests/player_input_coverage_test.gd::world.raycast_unfocused",
                "evidence_report": f"output/3d/player-input-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "复用 world.raycast_unfocused：在空目标射线前景按 E，断言没有 interaction_requested、focused 仍为空且完整 checkpoint 不变。",
            })
            player_unfocused_input += 1
        if row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:48-51" and "interaction_requested.emit(focused)" in row["branch_or_guard"]:
            row.update({
                "catalog_id": "world.prop_on",
                "test": "Godot/three_d/tests/player_input_coverage_test.gd::world.prop_on",
                "evidence_report": f"output/3d/player-input-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "桌面 Godot 进程保持 captured 鼠标模式，按 E 由 _unhandled_input 命中台灯真实锚点并经 Player 信号连接 World.request_action；断言信号目标、灯状态切换及完整 Run 保持不变。",
            })
            player_interaction_signal += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:482-484" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.services_open",
                "test": "Godot/three_d/tests/world_coverage_test.gd::world.services_open",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "复用 world.services_open 语义 ID；通过真实 Tavern/SearchSite 锚点射线调 request_action，断言搜索模式面板打开、站点 ID 正确、玩家控制禁用且 Run 快照不变。",
            })
            world_search_evidence += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:485-487" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.services_open",
                "test": "Godot/three_d/tests/world_coverage_test.gd::world.services_open",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "复用 world.services_open 语义 ID；通过真实货架 shop 锚点射线调 request_action，断言单品模式面板打开、商品 ID 正确、玩家控制禁用且 Run 快照不变。",
            })
            world_product_evidence += 1
        if row["player_reachable"] == "no" and row["disposition"] == "reachable_unmapped":
            row["disposition"] = "unreachable_or_not_transition"
            row["notes"] += " 当前树归因：损坏/篡改存档恢复拒绝或底层写盘失败，不计入正常玩家可达缺口；保留为系统防御分支记录。"
            reclassified_nonplayer += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:106-107" and row["catalog_id"] == "-":
            row.update({
                "outcome": "not_a_transition",
                "disposition": "unreachable_or_not_transition",
                "notes": "playtest_seed 只决定是否显示 save_notice；此分支不改变权威 Run、World 或存档状态，不计为状态转移。",
            })
            presentation_only += 1
        if row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:67-69" and "next == focused" in row["branch_or_guard"]:
            row.update({
                "outcome": "not_a_transition",
                "test": "Godot/three_d/tests/world_coverage_test.gd::focus_repeat_idempotent",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "unreachable_or_not_transition",
                "notes": "连续更新同一准星目标只抑制重复 focus_changed UI 信号；focused 与权威 Run/World/存档状态均不变。world_coverage_test.gd 现直接断言再次 update_focus 后目标仍相同且信号计数不增加，因此分类为非状态转移。",
            })
            focus_idempotence += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:665-669" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.autosave",
                "test": "Godot/three_d/tests/world_coverage_test.gd::world.autosave",
                "evidence_report": f"output/3d/world-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "测试态直接执行 World._process(0.6)，验证达到自动保存间隔后 save_clock 清零、隔离磁盘 envelope 状态与完整内存 checkpoint 一致、保存提示更新，并删除临时文件。目录新增 world.autosave 对应玩家离散写盘结果。",
            })
            world_autosave += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:626-632" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.window_focus_out",
                "test": "Godot/three_d/tests/world_focus_out_test.gd::world.window_focus_out",
                "evidence_report": f"output/3d/world-focus-out-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "独立非 --test Godot 套件在回归专用 HOME 下直接注入 WINDOW_FOCUS_OUT 通知，验证服务面板关闭、暂停与玩家控制禁用，且隔离磁盘快照等于完整内存 checkpoint；正式存档不会被触碰。",
            })
            world_focus_out += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:622-625" and row["catalog_id"] == "-":
            row.update({
                "catalog_id": "world.window_close_request",
                "test": "Godot/three_d/tests/world_close_request_test.gd::world.window_close_request",
                "evidence_report": f"output/3d/world-close-request-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "WM_CLOSE_REQUEST 通知在 readiness 且隔离存档槽可写时触发；测试读回完整 checkpoint 与通知前状态一致，确认保存先于退出请求。",
            })
            world_close_request += 1
        if row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] == "Godot/three_d/scripts/world.gd:511-512" and row["catalog_id"] == "world.services_open":
            row["disposition"] = "catalogued_weak"
            row["notes"] += " 当前树归因：已有 world.services_open ID；吧台实体锚点的射线/输入到打开面板仍缺独立集成后置断言，列为弱证据，不计未登记 ID。"
            reclassified_weak += 1
        if "20260925-103506" in row["evidence_report"] or "20260925-105659" in row["evidence_report"]:
            row["evidence_report"] = row["evidence_report"].replace("20260925-103506/report.json", LATEST_REPORT).replace("20260925-105659/report.json", LATEST_REPORT)

    run_restore_evidence = {
        "Godot/three_d/rules/run_checkpoint.gd:33-34": "独立单字段非法样例分别触发资金/风声边界和非 Dictionary 桌面守卫；每例都断言 restore 返回 null、输入快照不变且基准 Run capture 不变。",
        "Godot/three_d/rules/run_checkpoint.gd:70-71": "未知 scene_id 单字段样例从合法 Run 快照构造，确认命中场景存在性拒绝且不改输入或活体 Run。",
        "Godot/three_d/rules/run_checkpoint.gd:90-91": "offer_index=-1 与等于 fixedRoutes.size() 分别单字段拒绝，输入快照和活体 Run 均保持不变。",
        "Godot/three_d/rules/run_checkpoint.gd:96": "arrival_completed 大于 completed.size() 的单字段样例被拒绝，且输入快照及活体 Run 不变。",
        "Godot/three_d/rules/run_checkpoint.gd:97-101": "venue_history 的非字符串、未知场景、重复场景及末项与 scene_id 不符分别由合法快照单字段构造，均拒绝且不变更状态。",
        "Godot/three_d/rules/run_checkpoint.gd:102": "通过真实 Run.start/enter_table/settle_table/transfer_venue 生成合法转场快照，再单独清空 transfer_log，命中历史长度拒绝且两份基线不变。",
        "Godot/three_d/rules/run_checkpoint.gd:103-109": "真实转场快照逐项篡改 hop 的 from/to、fee 类型/下界、after_tables 类型/递增/范围，并单独错置 arrival_completed；每个负例只改一个字段并拒绝。",
        "Godot/three_d/rules/run_checkpoint.gd:109": "通过真实转场 API 生成合法快照后单独错置 arrival_completed，断言拒绝、输入快照不变且活体 Run 不变。",
        "Godot/three_d/rules/run_checkpoint.gd:116-117": "分别构造未知抵押物、非贵重道具抵押、无活动牌桌留抵押物三种单字段快照，均被拒绝且输入及活体 Run 不变。",
    }
    for row in branches:
        if row["source_file"] == "Godot/three_d/rules/run_checkpoint.gd" and row["source_line"] in run_restore_evidence:
            row.update({
                "test": "Godot/three_d/tests/run_restore_bounds_test.gd::invalid_fields_rejected",
                "evidence_report": f"output/3d/persistence-run-coverage.json;{LATEST_REPORT}",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": run_restore_evidence[row["source_line"]],
            })

    transfer_compatibility = {
        "Godot/three_d/rules/run.gd:104": (
            "Godot/three_d/tests/transfer_coverage_test.gd::empty_plan",
            "transfer_coverage_test.gd 实际执行旧活动存档的空 variant_plan 转场；核对转场成功、费用/行动力变化、牌桌种子与玩家机会保持、venue_history 首次补入离开/到达酒馆，并验证生成计划有效。",
        ),
        "Godot/three_d/rules/run.gd:109-113": (
            "Godot/three_d/tests/transfer_coverage_test.gd::v1_plan",
            "从合法 v1 checkpoint 移除 events/opponents/room_layout 后恢复并实际转场；核对旧牌桌种子保留、缺失维度按默认路线/对手/线性房间补齐、计划仍有效且转场账目正确。",
        ),
        "Godot/three_d/rules/run.gd:115-116": (
            "Godot/three_d/tests/transfer_coverage_test.gd::transfer.success",
            "成功转场夹具开始时 venue_history 为空；测试断言一次转场后记录 [smoky-den, high-rise-suite]，避免漏记离开酒馆导致后续重访校验失效。",
        ),
    }
    transfer_compatibility_rows = Counter()
    for row in branches:
        key = row["source_line"]
        if (row["source_file"] != "Godot/three_d/rules/run.gd"
                or row["entry"] != "transfer_venue"
                or key not in transfer_compatibility):
            continue
        test, notes = transfer_compatibility[key]
        row.update({
            "catalog_id": "transfer.success",
            "test": test,
            "evidence_report": f"output/3d/transfer-coverage.json;{LATEST_REPORT}",
            "evidence_strength": "strong",
            "disposition": "catalogued_strong",
            "notes": notes,
        })
        transfer_compatibility_rows[key] += 1
    if any(transfer_compatibility_rows[key] != 1 for key in transfer_compatibility):
        raise SystemExit(f"Unexpected legacy transfer evidence rows: {dict(transfer_compatibility_rows)}")

    interaction_evidence = {
        ("Godot/three_d/scripts/player.gd", "Godot/three_d/scripts/player.gd:43-44", "world.focus_controls_disabled"): {
            "test": "Godot/three_d/tests/player_input_coverage_test.gd::world.focus_controls_disabled",
            "evidence_report": "output/3d/player-input-coverage.json",
            "notes": "窗口输入套件在 captured 模式下向 controls_enabled=false 的 Player 投递鼠标移动与映射 E 键，断言 Transform、相机、完整 checkpoint 和交互信号均不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:511-512", "world.services_open"): {
            "test": "Godot/three_d/tests/world_coverage_test.gd::physical_bar_services_open",
            "evidence_report": "output/3d/world-coverage.json",
            "notes": "窗口输入套件从 Tavern/BarService 实体锚点射线命中后经映射 E 键信号链打开 bar 面板；核对模式、控件锁、准星隐藏且完整 Run capture 不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:515-516", "world.show_run_panel"): {
            "test": "Godot/three_d/tests/world_coverage_test.gd::physical_stash_exit_preview",
            "evidence_report": "output/3d/world-coverage.json",
            "notes": "窗口输入套件从烟雾酒馆实体撤离门经映射 E 键信号链打开 extract 面板；核对当前出口不可用提示、按钮禁用、面板和完整 checkpoint 不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:515-516", "world.extract_confirm"): {
            "test": "Godot/three_d/tests/world_coverage_test.gd::physical_stash_exit_preview + extract_confirm",
            "evidence_report": "output/3d/world-coverage.json",
            "notes": "实体门的 E 键打开撤离预览并与实际确认分开断言；同套件随后通过 extract 按钮核对成功后的位置、金库到账、随身清空和面板关闭。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:518-520", "world.room_door_blocked"): {
            "test": "Godot/three_d/tests/world_coverage_test.gd::room_door_blocked",
            "evidence_report": "output/3d/world-coverage.json",
            "notes": "窗口输入套件在未完成货运桌时从真实账房门锚点按映射 E，核对留在原房、阻挡提示及完整 checkpoint 不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:879-885", "world.services_open"): {
            "test": "Godot/three_d/tests/world_coverage_test.gd::inventory_key_services_toggle",
            "evidence_report": "output/3d/world-coverage.json",
            "notes": "窗口输入套件确认物理 B 键映射到 inventory；真实调用 World 输入处理后分别打开和关闭背包服务面板，Run capture 不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:879-885", "world.services_close"): {
            "test": "Godot/three_d/tests/world_coverage_test.gd::inventory_key_services_toggle",
            "evidence_report": "output/3d/world-coverage.json",
            "notes": "窗口输入套件以第二次映射 B 键关闭服务面板，核对控制恢复、面板隐藏且 Run capture 不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:951-951", "persistence_restore.playtest_save_blocked"): {
            "test": "Godot/three_d/tests/playtest_seed_test.gd::blocked_save_preserved",
            "evidence_report": "output/3d/playtest-seed-coverage.json",
            "notes": "playtest 模式预置隔离有效存档后调用直接保存；核对返回拒绝、磁盘原字节/哈希不变且完整内存 checkpoint 不变。",
        },
        ("Godot/three_d/scripts/world.gd", "Godot/three_d/scripts/world.gd:967-967", "persistence_restore.playtest_save_blocked"): {
            "test": "Godot/three_d/tests/playtest_seed_test.gd::blocked_load_preserved",
            "evidence_report": "output/3d/playtest-seed-coverage.json",
            "notes": "playtest 模式预置与当前内存不同的有效隔离存档后调用加载；核对完整内存 checkpoint、saving_enabled 和原存档字节/哈希均不变。",
        },
    }
    for row in branches:
        key = (row["source_file"], row["source_line"], row["catalog_id"])
        if key in interaction_evidence:
            row.update(interaction_evidence[key])
            row.update({"evidence_strength": "strong", "disposition": "catalogued_strong"})

    # World/table orchestration is a call-site layer over already catalogued
    # poker and world outcomes. Reuse those IDs; do not expand the catalog for
    # duplicate wrappers around the same accepted/rejected result.
    orchestration = {
        "Godot/three_d/scripts/world.gd:635-636": {
            "ids": "-",
            "test": "Godot/three_d/tests/table_integration.gd::Repeated start cannot charge twice",
            "strength": "none",
            "outcome": "not_a_transition",
            "disposition": "unreachable_or_not_transition",
            "notes": "start_table 的未入座/已有桌局/暂停早退不改变权威状态；只有入座且处于可开局面板时按钮可用，开始后面板刷新，暂停时桌面操作面板隐藏。重复调用的 no-op 有测试，玩家输入不能从这些 UI 状态再次触发该入口，不借用规则层拒绝 ID。",
        },
        "Godot/three_d/scripts/world.gd:642-645": {
            "ids": "entry.success",
            "test": "Godot/three_d/tests/table_integration.gd::Starting table pays buy-in once",
            "strength": "strong",
            "notes": "World.start_table 成功调用 Run.enter_table；复用 entry.success，测试断言只扣一次 buy-in 且创建真实牌桌。",
        },
        "Godot/three_d/scripts/world.gd:648-649": {
            "ids": "-",
            "test": "Godot/three_d/tests/table_integration.gd::Pause freezes timer and blocks player input;Godot/three_d/tests/services_save_test.gd::Services freeze an AI turn, direct beat advance, and hidden table actions",
            "strength": "none",
            "outcome": "not_a_transition",
            "disposition": "unreachable_or_not_transition",
            "notes": "play_action 的暂停/服务面板/无桌/节拍锁早退不改变权威状态；控制按钮在暂停、服务面板、无桌及节拍锁状态下隐藏或禁用，测试分别验证这些 no-op。它们是包装层输入被拦截，不借用 request_action 或规则层拒绝 ID。",
        },
        "Godot/three_d/scripts/world.gd:653-656": {
            "ids": "poker_action.fold;poker_action.call;poker_action.check;poker_action.raise;poker_action.all_in",
            "test": "Godot/three_d/tests/table_integration.gd::HUD button submits exactly one legal action",
            "strength": "strong",
            "notes": "World.play_action 只是牌桌动作的世界侧分派；实牌桌 HUD 测试验证接受动作令 revision 恰增 1，动作后继由对应 poker_action ID 承接。",
        },
        "Godot/three_d/scripts/world.gd:658-662": {
            "ids": "poker_progress.next_hand",
            "test": "Godot/three_d/tests/table_integration.gd::Second hand was played through the HUD",
            "strength": "strong",
            "notes": "World.continue_hand 经真实下一手按钮进入规则层 next_hand；牌桌集成验证第二手与终局，后继复用既有牌桌进度/终局结果 ID。",
        },
        "Godot/three_d/scripts/world.gd:670-671": {
            "ids": "-",
            "test": "Godot/three_d/tests/services_save_test.gd::Services freeze an AI turn, direct beat advance, and hidden table actions",
            "strength": "strong",
            "outcome": "not_a_transition",
            "disposition": "unreachable_or_not_transition",
            "notes": "AI 行动待执行时打开服务面板，调用 _process 后完整 checkpoint 不变，证明本行为冻结/no-op；面板自身状态另由 world.modal_guard 覆盖，不把定时器早退再算一个转移。",
        },
        "Godot/three_d/scripts/world.gd:672-673": {
            "ids": "-",
            "test": "Godot/three_d/tests/table_integration.gd::Pause freezes timer and blocks player input",
            "strength": "strong",
            "outcome": "not_a_transition",
            "disposition": "unreachable_or_not_transition",
            "notes": "无桌/暂停/未入座时 _process 早退，不写 Run/Table/World/存档权威状态；暂停场景有 revision 不变断言，其余状态下 table_game 为空或面板隐藏，属于调度包装层 no-op，不借用其他入口的拒绝 ID。",
        },
        "Godot/three_d/scripts/world.gd:681-681": {
            "ids": "poker_action.fold;poker_action.call;poker_action.check;poker_action.raise;poker_action.all_in;poker_progress.flop;poker_progress.turn;poker_progress.river;poker_progress.showdown;poker_progress.advance_finished_hand",
            "test": "Godot/three_d/tests/table_integration.gd::World process advances exactly one AI action or street",
            "strength": "strong",
            "notes": "本轮牌桌全流程改由 World._process 驱动；每个非玩家节拍都断言 revision 恰增 1 且公开状态变化，后继归属既有 poker_action / poker_progress ID。",
        },
        "Godot/three_d/scripts/world.gd:684-685": {
            "ids": "-",
            "test": "Godot/three_d/tests/services_save_test.gd::Services freeze an AI turn, direct beat advance, and hidden table actions",
            "strength": "strong",
            "outcome": "not_a_transition",
            "disposition": "unreachable_or_not_transition",
            "notes": "服务面板打开时直接调用 advance_table_beat 后完整 checkpoint 不变；暂停/无桌/非 playing 状态同属调度早退，均不产生权威状态后继，不把这个 wrapper no-op 复用为新的 guard ID。",
        },
        "Godot/three_d/scripts/world.gd:687-688": {
            "ids": "poker_progress.flop;poker_progress.turn;poker_progress.river;poker_progress.showdown;poker_progress.advance_finished_hand",
            "test": "Godot/three_d/tests/table_integration.gd::World scheduler advances a street when no actor is pending",
            "strength": "strong",
            "notes": "固定种子完整牌局中统计 currentActorId 为空的真实调度拍；测试断言至少一次抵达该分支，且每次 World._process 后 revision 恰增 1、公开牌桌状态变化，复用既有 poker_progress 街道推进 ID。",
        },
        "Godot/three_d/scripts/world.gd:690-692": {
            "ids": "poker_action.fold;poker_action.call;poker_action.check;poker_action.raise;poker_action.all_in",
            "test": "Godot/three_d/tests/table_integration.gd::World process advances exactly one AI action or street",
            "strength": "strong",
            "notes": "本轮全牌局改由 World._process 驱动真实 AI 行动；逐拍断言 revision 与公开牌桌状态变化，动作语义由既有 poker_action ID 承接。",
        },
        "Godot/three_d/scripts/world.gd:1047-1051": {
            "ids": "world.leave_forced_pressure_exit;world.services_close;world.travel_landing",
            "test": "Godot/three_d/tests/routes_items_test.gd::Pressure enforcement closes services and forces the player back to stash",
            "strength": "strong",
            "notes": "高风声且现金不足时，从实际酒保面板执行有效 intel 服务动作，经 World.service_action→check_pressure 关闭面板并强制回藏匿点；断言强制失败结果、位置及损失提示，复用既有 forced-exit/close/travel ID。",
        },
        "Godot/three_d/scripts/world.gd:554-560": {
            "ids": "world.travel_landing",
            "test": "Godot/three_d/tests/world_coverage_test.gd::travel_landing",
            "strength": "strong",
            "notes": "测试对 stash/tavern/ledger/mirror/embers 五目的地断言房间、落点、标题，并逐个核对 active_table_id、table_target、seat_camera 与 cards_root 均指向目标桌房；four_tables_test.gd 与 room_pool_test.gd 也经真实门到达。",
        },
    }
    for target_rows in (branches, old_gaps):
        for row in target_rows:
            mapping = orchestration.get(row["source_line"])
            if mapping is None:
                continue
            row.update({
                "catalog_id": mapping["ids"],
                "outcome": mapping.get("outcome", row["outcome"]),
                "test": mapping["test"],
                "evidence_report": f"{LATEST_REPORT}",
                "evidence_strength": mapping["strength"],
                "disposition": mapping.get("disposition", "catalogued_weak" if mapping["strength"] == "weak" else "catalogued_strong"),
                "notes": mapping["notes"],
            })

    ai_dispatch_rows = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/scripts/world.gd"
                and row["entry"] == "advance_table_beat"
                and row["source_line"] == "Godot/three_d/scripts/world.gd:690-692"):
            row["source_line"] = "Godot/three_d/scripts/world.gd:689-692"
            row["notes"] += " 同时覆盖 `elif actor_id != player` 的 AI 调度分派条件（world.gd:689）；测试由 World._process 驱动真实对手行动。"
            ai_dispatch_rows += 1
    if ai_dispatch_rows != 1:
        raise SystemExit(f"Unexpected AI dispatch rows: {ai_dispatch_rows}")

    # `act()` rechecks legality before mutating the authoritative table. The
    # same 12 legality outcomes are asserted at both the query and command
    # boundary by poker_guard_coverage_test.gd; record the shared rejection
    # gate without creating duplicate semantic IDs.
    act_legality_guard_ids = {
        "poker_guard.not_playing", "poker_guard.wrong_turn", "poker_guard.unknown_actor",
        "poker_guard.folded_actor", "poker_guard.empty_stack", "poker_guard.raise_used",
        "poker_guard.open_short", "poker_guard.matched_raise_short", "poker_guard.raise_short",
        "poker_guard.check_owes", "poker_guard.call_zero", "poker_guard.call_short",
    }
    act_legality_guard_rows = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/table.gd"
                and row["entry"] == "legal_actions"
                and row["catalog_id"] in act_legality_guard_ids):
            source_ref = "Godot/three_d/rules/table.gd:82-83"
            refs = row["source_line"].split(";")
            if source_ref not in refs:
                row["source_line"] += f";{source_ref}"
            row["notes"] += " 测试还经 Table.act 命中该共享 legality gate（table.gd:82-83），并断言命令拒绝且完整 checkpoint 不变；仍复用同一语义 ID。"
            act_legality_guard_rows += 1
    if act_legality_guard_rows != len(act_legality_guard_ids):
        raise SystemExit(f"Unexpected Table.act shared legality guard rows: {act_legality_guard_rows}")

    # Record the general-exit dispatch predicate as part of the fee outcome
    # that its existing parameterized route guard test actually asserts.
    general_surcharge_rows = 0
    for row in branches:
        if row["catalog_id"] == "route_guard.general_surcharge" and row["source_line"] == "Godot/three_d/rules/routes.gd:11":
            row["source_line"] = "Godot/three_d/rules/routes.gd:10-11"
            row["notes"] += " 覆盖一般出口 kind 分派条件（routes.gd:10）；用例验证 fee 与 vault 的精确后继。"
            general_surcharge_rows += 1
    if general_surcharge_rows != 1:
        raise SystemExit(f"Unexpected general surcharge branch rows: {general_surcharge_rows}")

    # The normal UI start path passes the committed per-table seed through the
    # default start_table argument. Reuse entry.success and its end-to-end test.
    table_start_rows = [
        row for row in branches
        if row["source_file"] == "Godot/three_d/scripts/world.gd"
        and row["source_line"] == "Godot/three_d/scripts/world.gd:642-645"
        and row["catalog_id"] == "entry.success"
    ]
    if len(table_start_rows) != 1:
        raise SystemExit(f"Expected one mapped World.start_table success row, got {len(table_start_rows)}")
    seed_row = table_start_rows[0].copy()
    seed_row.update({
        "branch_or_guard": "默认 seed_value < 0 → 读取 variant_plan.table_seeds[active_table_id]",
        "source_line": "Godot/three_d/scripts/world.gd:637-638",
        "test": "Godot/three_d/tests/run_variants_test.gd::Normal table start uses committed seed",
        "evidence_report": f"output/3d/run-variants.json;{LATEST_REPORT}",
        "notes": "正常出发后的无参 start_table() 读取已提交的牌局种子；run_variants_test.gd 断言实际牌局 seed 等于 variant_plan.table_seeds，重载后牌堆不重掷。复用 entry.success，不把确定性参数选择重复计为新状态结果。",
    })
    branches.append(seed_row)

    checkpoint_seat_rows = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/table_checkpoint.gd"
                and row["entry"] == "restore"
                and row["source_line"] == "Godot/three_d/rules/table_checkpoint.gd:30-31"
                and row["catalog_id"] == "persistence_table.invalid_snapshot_rejected"):
            row["notes"] += " 新增对 0/1/2 号座位分别注入 stack=-1 的正式回归；每次均拒绝恢复并断言活体 Table checkpoint 不变，覆盖固定三座循环在每个索引的该拒绝守卫。"
            checkpoint_seat_rows += 1
    if checkpoint_seat_rows != 1:
        raise SystemExit(f"Unexpected checkpoint seat validation rows: {checkpoint_seat_rows}")

    # Keep source-level dispatch / telemetry outcomes visible in the audit.
    # These branches do not mutate authoritative game state and therefore do
    # not create transition IDs, but omitting them would make the source list
    # look more complete than it is.
    non_transition_sites = [
        {
            "source_file": "Godot/three_d/rules/opponent.gd",
            "entry": "choose_with_odds",
            "source_line": "Godot/three_d/rules/opponent.gd:36",
            "branch_or_guard": "match definition.archetype 分派到本地策略参数",
            "player_reachable": "yes",
            "outcome": "not_a_transition",
            "test": "Godot/three_d/tests/opponent_profiles_test.gd",
            "evidence_report": "",
            "evidence_strength": "none",
            "disposition": "unreachable_or_not_transition",
            "notes": "该 match 只调整局部 profile 并选择后续 action 名称；权威牌桌状态由 Table.act 改变。现有策略分布测试覆盖原型差异，但不把 AI 选择分支本身当作独立状态转移。",
        },
        {
            "source_file": "Godot/three_d/scripts/world.gd",
            "entry": "trace_playtest",
            "source_line": "Godot/three_d/scripts/world.gd:127-129",
            "branch_or_guard": "试玩 trace 目录创建失败 → 报错并停止写遥测",
            "player_reachable": "yes",
            "outcome": "not_a_transition",
            "test": "",
            "evidence_report": "",
            "evidence_strength": "none",
            "disposition": "unreachable_or_not_transition",
            "notes": "只影响 user:// 下的 JSONL 试玩遥测文件；不改 Run、Table、World 权威状态或正式存档。目录创建失败未由专门测试注入。",
        },
        {
            "source_file": "Godot/three_d/scripts/world.gd",
            "entry": "trace_playtest",
            "source_line": "Godot/three_d/scripts/world.gd:132-133;Godot/three_d/scripts/world.gd:137-138",
            "branch_or_guard": "试玩 trace 文件已存在 → 以追加模式打开并移至末尾；否则新建/覆盖打开",
            "player_reachable": "yes",
            "outcome": "not_a_transition",
            "test": "Godot/three_d/tests/playtest_seed_test.gd",
            "evidence_report": "",
            "evidence_strength": "none",
            "disposition": "unreachable_or_not_transition",
            "notes": "只决定遥测文件打开模式，不改权威游戏状态；试玩 trace 测试检查记录输出，不将追加/新建视为独立玩法结果。",
        },
        {
            "source_file": "Godot/three_d/scripts/world.gd",
            "entry": "trace_playtest",
            "source_line": "Godot/three_d/scripts/world.gd:133-136",
            "branch_or_guard": "试玩 trace 文件打开失败 → 报错并停止写遥测",
            "player_reachable": "yes",
            "outcome": "not_a_transition",
            "test": "",
            "evidence_report": "",
            "evidence_strength": "none",
            "disposition": "unreachable_or_not_transition",
            "notes": "只影响 user:// 下的 JSONL 试玩遥测写入；不改 Run、Table、World 权威状态或正式存档。文件打开失败未由专门测试注入。",
        },
    ]
    for site in non_transition_sites:
        row = {field: "" for field in branch_fields}
        row.update(site)
        row["catalog_id"] = "-"
        branches.append(row)

    # A successful quote and its actual transfer command are exercised for
    # each invalid reason; the wrapper's common rejection gate is not a new ID.
    transfer_rejection_rows = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/run.gd"
                and row["entry"] == "transfer_venue"
                and row["catalog_id"].startswith("transfer.")
                and row["catalog_id"] not in {"transfer.success", "transfer.stale_revision"}):
            source_ref = "Godot/three_d/rules/run.gd:103-103"
            refs = row["source_line"].split(";")
            if source_ref not in refs:
                row["source_line"] += f";{source_ref}"
            row["notes"] += " transfer_coverage_test.gd 对报价与实际 transfer_venue 命令均断言；本行 also 覆盖统一 quote.reason 拒绝门（run.gd:103），完整 Run checkpoint 不变。"
            transfer_rejection_rows += 1
    if transfer_rejection_rows != 10:
        raise SystemExit(f"Unexpected transfer rejection guard rows: {transfer_rejection_rows}")

    # The service-reason kind dispatch selects which accepted/rejected
    # service outcome applies. Existing boundary suites execute service_action
    # and assert the complete Run checkpoint for each listed outcome.
    service_dispatch_ids = {
        "Godot/three_d/rules/run.gd:281-281": {
            "service.not_stocked", "service.buy_cash", "service.full_bag", "service.buy",
        },
        "Godot/three_d/rules/run.gd:291-291": {
            "service.cool_unavailable", "service.drink_unowned",
            "service.cool_cash", "service.drink", "service.cool",
        },
        "Godot/three_d/rules/run.gd:298-298": {
            "service.intel_unavailable", "service.intel",
        },
    }
    service_dispatch_mappings = set()
    for row in branches:
        if row["entry"] != "service_action" or row["catalog_id"] == "-":
            continue
        source_refs = row["source_line"].split(";")
        for source_ref, ids in service_dispatch_ids.items():
            if row["catalog_id"] in ids:
                if source_ref not in source_refs:
                    row["source_line"] += f";{source_ref}"
                row["notes"] += f" service_reason 的 kind 分派条件 {source_ref.rsplit(':', 1)[1]} 由同一套端到端服务用例命中；此处是已有结果的选择路径，不另增 ID。"
                service_dispatch_mappings.add((source_ref, row["catalog_id"]))
    expected_dispatch_rows = sum(map(len, service_dispatch_ids.values()))
    if len(service_dispatch_mappings) != expected_dispatch_rows:
        raise SystemExit(f"Unexpected service dispatch mappings: {len(service_dispatch_mappings)}/{expected_dispatch_rows}")

    # Ordered rewardRules are tested through real settle_table calls with
    # exact inventory, stack-threshold, and collateral postconditions. Link
    # the pure selector implementation to the existing reward outcome IDs.
    reward_ids = {
        "settlement.ivory", "settlement.lighter", "settlement.ruby", "settlement.emerald",
        "settlement.pearl", "settlement.watch", "settlement.bond", "settlement.antique",
        "settlement.idol", "settlement.promissory",
    }
    reward_selector_rows = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/run.gd"
                and row["entry"] == "settle_table"
                and row["catalog_id"] in reward_ids
                and row["source_line"] == "Godot/three_d/rules/run.gd:197-202"):
            row["source_line"] += ";Godot/three_d/rules/run.gd:461-467"
            row["notes"] += " settlement_coverage_test.gd 的该奖励用例还执行有序 reward_for_table selector；矩阵覆盖 minStack、inventoryHas/inventoryMissing、collateralReturned 的通过/回退及四桌兜底发奖，并断言结算后的准确库存与奖励 ID。"
            reward_selector_rows += 1
    if reward_selector_rows != len(reward_ids):
        raise SystemExit(f"Unexpected settlement reward selector rows: {reward_selector_rows}/{len(reward_ids)}")

    # `shop_stock()` is a read-only projection, not a separate state result,
    # but both the committed-plan path and legacy save fallback determine
    # which service purchase can follow. The run-variants test now verifies
    # the legacy second-stage phone through purchase in all four venues.
    stock_projection_rows = 0
    for row in branches:
        if (row["source_file"] == "Godot/three_d/rules/run_variants.gd"
                and row["entry"] == "generate"
                and row["source_line"] == "Godot/three_d/rules/run_variants.gd:12-19"):
            row["source_line"] += ";Godot/three_d/rules/run.gd:306-312"
            legacy_test = "Godot/three_d/tests/run_variants_test.gd::Legacy stage-two shelf and phone purchase across venues"
            tests = row["test"].split(";")
            if legacy_test not in tests:
                row["test"] += f";{legacy_test}"
            row["evidence_report"] = f"output/3d/run-variants.json;{LATEST_REPORT}"
            row["notes"] += " 同一回归现还覆盖 Run.shop_stock 的变体计划投影及无计划旧存档回退（run.gd:306-312）；四家酒馆的第二阶段旧存档都恢复一次性手机，并成功购买、精确扣款/行动力。该只读货架选择本身不新增 Run 状态转移 ID。"
            stock_projection_rows += 1
    if stock_projection_rows != 1:
        raise SystemExit(f"Unexpected shop_stock projection rows: {stock_projection_rows}")

    if partial_bankroll != 1 or entry_heat_cap != 1 or settlement_heat_relief != 1 or player_raise_pattern != 1 or room_layout_selected != 1 or room_layout_locked != 2 or poker_short_blinds != 1 or poker_seeded_deals != 1 or poker_open_raise_right != 1 or player_pause_input != 1 or player_interaction_signal != 1 or player_look != 1 or player_movement != 1 or player_unfocused_input != 1 or world_search_evidence != 1 or world_product_evidence != 1 or reclassified_nonplayer != 6 or presentation_only != 1 or focus_idempotence != 1 or world_autosave != 1 or world_focus_out != 1 or world_close_request != 1 or reclassified_weak != 1:
        raise SystemExit(f"Unexpected reconciliation counts: partial={partial_bankroll}, heat_cap={entry_heat_cap}, settlement_relief={settlement_heat_relief}, player_pattern={player_raise_pattern}, room_layout={room_layout_selected}, layout_locked={room_layout_locked}, poker_short_blinds={poker_short_blinds}, poker_seeded_deals={poker_seeded_deals}, poker_open_raise_right={poker_open_raise_right}, player_pause_input={player_pause_input}, player_interaction_signal={player_interaction_signal}, player_look={player_look}, player_movement={player_movement}, player_unfocused_input={player_unfocused_input}, search_evidence={world_search_evidence}, product_evidence={world_product_evidence}, nonplayer={reclassified_nonplayer}, presentation={presentation_only}, focus_idempotence={focus_idempotence}, autosave={world_autosave}, focus_out={world_focus_out}, close_request={world_close_request}, weak={reclassified_weak}")

    current_gaps = [
        row.copy() for row in old_gaps
        if row["player_reachable"] == "yes"
        and row["catalog_id"] == "-"
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:61-62")
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:175")
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] == "Godot/three_d/rules/run.gd:205")
        and not (row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:119-120")
        and not (row["source_file"] == "Godot/three_d/rules/run_variants.gd" and row["source_line"] == "Godot/three_d/rules/run_variants.gd:36")
        and not (row["source_file"] == "Godot/three_d/rules/run.gd" and row["source_line"] in {"Godot/three_d/rules/run.gd:147-148", "Godot/three_d/rules/run.gd:149"})
        and not (row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:44-46")
        and not (row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:47-50")
        and not (row["source_file"] == "Godot/three_d/rules/table.gd" and row["source_line"] == "Godot/three_d/rules/table.gd:102-102")
        and not (row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] in {"Godot/three_d/scripts/player.gd:38-42", "Godot/three_d/scripts/player.gd:45-47", "Godot/three_d/scripts/player.gd:48-51", "Godot/three_d/scripts/player.gd:50-51", "Godot/three_d/scripts/player.gd:56-60"})
        and not (row["source_file"] == "Godot/three_d/scripts/player.gd" and row["source_line"] == "Godot/three_d/scripts/player.gd:67-69")
        and not (row["source_file"] == "Godot/three_d/scripts/world.gd" and row["source_line"] in {"Godot/three_d/scripts/world.gd:482-484", "Godot/three_d/scripts/world.gd:485-487", "Godot/three_d/scripts/world.gd:622-625", "Godot/three_d/scripts/world.gd:626-632", "Godot/three_d/scripts/world.gd:665-669"})
        and row["catalog_id"] == "-"
        and row["disposition"] == "reachable_unmapped"
    ]
    weak_evidence = [row.copy() for row in branches if row["disposition"] == "catalogued_weak"]
    literal_reachable_without_id = [
        row for row in branches
        if row["player_reachable"] == "yes" and row["catalog_id"] == "-"
    ]
    if any(row["disposition"] == "reachable_unmapped" for row in literal_reachable_without_id):
        raise SystemExit("A player-reachable row without a catalog ID remains unmapped")
    if any(not row["notes"].strip() for row in literal_reachable_without_id):
        raise SystemExit("A player-reachable row without a catalog ID lacks a disposition rationale")
    accepted_without_id = sum(row["outcome"] == "accepted" for row in literal_reachable_without_id)
    for row in current_gaps:
        if "20260925-103506" in row["evidence_report"] or "20260925-105659" in row["evidence_report"]:
            row["evidence_report"] = row["evidence_report"].replace("20260925-103506/report.json", LATEST_REPORT).replace("20260925-105659/report.json", LATEST_REPORT)

    flush_rows = 0
    for row in branches:
        if row["source_file"].endswith("/save_store.gd") and "store_var/flush" in row["branch_or_guard"]:
            row.update({
                "branch_or_guard": "拒绝：临时文件写入/刷新返回错误，关闭文件并清理 .tmp，保留旧存档",
                "catalog_id": "persistence_io.write_flush_rejected",
                "test": "Godot/three_d/tests/save_store_test.gd::write_flush_rejected",
                "evidence_report": "output/3d/persistence-io-coverage.json",
                "evidence_strength": "strong",
                "disposition": "catalogued_strong",
                "notes": "可控写入回调创建临时文件后返回 ERR_FILE_CANT_WRITE；断言错误返回、旧存档字节不变及临时文件删除。没有实际模拟磁盘写满或只读卷。",
            })
            flush_rows += 1
    if flush_rows != 1:
        raise SystemExit(f"Unexpected flush-error rows: {flush_rows}")

    mapped_ids: set[str] = set()
    for row in branches:
        for transition_id in row["catalog_id"].split(";"):
            if transition_id and transition_id != "-":
                if transition_id not in catalog_ids:
                    raise SystemExit(f"Unknown catalog ID in overlay: {transition_id}")
                mapped_ids.add(transition_id)
    missing_ids = catalog_ids - mapped_ids
    if missing_ids:
        raise SystemExit(f"Current catalog IDs lack a branch mapping: {sorted(missing_ids)}")

    regression_path = ROOT / LATEST_REPORT
    regression = json.loads(regression_path.read_text(encoding="utf-8"))
    passed_regression_tests = {
        item["test"] for item in regression.get("results", []) if item.get("status") == "PASS"
    }
    for row in branches:
        source = ROOT / row["source_file"]
        if not source.is_file():
            raise SystemExit(f"Missing source file: {row['source_file']}")
        if row["disposition"] == "catalogued_strong" and row["evidence_report"].strip() in ("", "-"):
            declared_tests = [test.split("::", 1)[0].rsplit("/", 1)[-1] for test in row["test"].split(";") if test.strip() not in ("", "-")]
            if declared_tests and all(test in passed_regression_tests for test in declared_tests):
                row["evidence_report"] = LATEST_REPORT
            else:
                raise SystemExit(f"Strong evidence lacks a report containing its passing test: {row['source_line']}")
        for path in row["test"].split(";"):
            path = path.split("::", 1)[0].strip()
            if path and path != "-" and not (ROOT / path).is_file():
                raise SystemExit(f"Missing test file: {path}")
        for path in row["evidence_report"].split(";"):
            path = path.strip()
            if path and path != "-" and not (ROOT / path).is_file():
                raise SystemExit(f"Missing evidence report: {path}")
    if len(current_gaps) != 0 or any(row["player_reachable"] != "yes" or row["catalog_id"] != "-" for row in current_gaps):
        raise SystemExit(f"Current player-path gap set is inconsistent: {len(current_gaps)} rows")

    source_files = {row["source_file"] for row in branches}
    for row in branches:
        source_files.update(re.findall(r"([A-Za-z0-9_./-]+\.gd):\d+(?:-\d+)?", row["source_line"]))
    line_maps = {}
    for source in source_files:
        if not source.endswith(".gd"):
            continue
        try:
            line_maps[source] = line_map(source)
        except subprocess.CalledProcessError:
            continue
    for row in branches:
        remap_source_refs(row, line_maps)

    continuation_rows = 0
    for row in branches:
        if row["source_file"].endswith("/table_checkpoint.gd") and "pot 或 currentActorId" in row["branch_or_guard"]:
            row["source_line"] += ";Godot/three_d/rules/table_checkpoint.gd:23-51;Godot/three_d/rules/table_checkpoint.gd:62-63;Godot/three_d/rules/table_checkpoint.gd:75-80"
            row["notes"] += " 续局字段拒绝矩阵另覆盖缺失/非法街道、日志、加注与折扣标记、行为画像、回合计数、庄位、阶段标记、上一行动、结算摘要，以及重复/已弃牌/无筹码行动队列；逐例断言输入快照和活体牌桌未变，复用 invalid_snapshot_rejected。"
            continuation_rows += 1
    if continuation_rows != 1:
        raise SystemExit(f"Unexpected continuation-field rows: {continuation_rows}")

    for line, guard, note in (
        (97, "拒绝：completed 中的牌桌缺少已完成的前置房间", "completion_checkpoint_test.gd 覆盖线性布局的非法顺序与叉路布局的合法顺序；损坏存档防御分支。"),
        (133, "拒绝：活动牌桌已完成或缺少前置房间", "completion_checkpoint_test.gd 覆盖活动牌桌与完成记录冲突、跳过前置房间；损坏存档防御分支。"),
    ):
        row = {field: "" for field in branch_fields}
        row.update({
            "source_file": "Godot/three_d/rules/run_checkpoint.gd",
            "entry": "restore（世界启动/加载时由 world.gd 调用）",
            "function_line": "22",
            "branch_or_guard": guard,
            "source_line": f"Godot/three_d/rules/run_checkpoint.gd:{line}",
            "outcome": "rejected",
            "player_reachable": "no",
            "catalog_id": "-",
            "test": "Godot/three_d/tests/completion_checkpoint_test.gd",
            "evidence_report": LATEST_REPORT,
            "evidence_strength": "strong",
            "disposition": "unreachable_or_not_transition",
            "notes": note,
        })
        branches.append(row)

    # This guard was added after the frozen A8 source baseline.
    world_source = "Godot/three_d/scripts/world.gd"
    world_lines = (ROOT / world_source).read_text(encoding="utf-8").splitlines()
    rigid_line = next(i for i, text in enumerate(world_lines, 1)
                      if "if not is_equal_approx(basis.determinant(), 1.0)" in text)
    restore_line = next(i for i, text in enumerate(world_lines, 1)
                        if text.startswith("func restore_checkpoint("))
    row = {field: "" for field in branch_fields}
    row.update({
        "module": "world", "source_file": world_source,
        "entry": "restore_checkpoint", "function_line": str(restore_line),
        "branch_or_guard": "拒绝：玩家或返回位置的旋转基底为零、缩放、剪切或非正常旋转",
        "source_line": f"{world_source}:{rigid_line}-{rigid_line + 1}",
        "outcome": "rejected", "player_reachable": "no",
        "catalog_id": "persistence_restore.invalid_transform",
        "test": "Godot/three_d/tests/world_restore_atomic_test.gd::basis_zero/basis_scaled/basis_sheared/return_basis_zero",
        "evidence_report": LATEST_REPORT, "evidence_strength": "strong",
        "disposition": "catalogued_strong",
        "notes": "损坏存档防御：正常控制器只保存刚体旋转。四个矩阵夹具逐例断言拒绝且活体世界快照不变；复用既有非法变换 ID，不新增覆盖分母。",
    })
    branches.append(row)

    write_csv(AUDIT / "current-tree-branch-inventory.csv", branch_fields, branches)
    write_csv(AUDIT / "current-tree-unmapped-player-path-gaps.csv", branch_fields, current_gaps)
    write_csv(AUDIT / "current-tree-weak-evidence.csv", branch_fields, weak_evidence)
    counts = Counter(row["disposition"] for row in branches)
    # This is the source revision used by the regression and overlay. Later
    # documentation-only commits are allowed; verify_reconciliation.py checks
    # that game rules, runtime scripts, tests, and catalog stayed unchanged.
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report = regression_path
    lifecycle_report = ROOT / "output/3d/lifecycle-coverage.json"
    function_counts = source_sweep["counts"]
    branch_site_counts = source_sweep["control_flow_site_counts"]
    source_file_count = len(source_sweep["source_sha256"])
    function_count = sum(function_counts.values())
    branch_site_count = sum(branch_site_counts.values())
    text = f"""# A8 当前树对账记录

- 证据源码基线 HEAD：`{head}`
- 当前目录：{len(catalog_ids)} 个唯一 ID，SHA-256 `{sha256(CATALOG)}`
- 采用的全量回归：`{LATEST_REPORT}`（必须由当前源码/测试重跑后更新本记录）
- 回归报告 SHA-256：`{sha256(report)}`
- lifecycle 覆盖报告 SHA-256：`{sha256(lifecycle_report)}`
- 当前分支清单 SHA-256：`{sha256(AUDIT / 'current-tree-branch-inventory.csv')}`
- 当前玩家路径缺口清单 SHA-256：`{sha256(AUDIT / 'current-tree-unmapped-player-path-gaps.csv')}`
- 当前弱证据清单 SHA-256：`{sha256(AUDIT / 'current-tree-weak-evidence.csv')}`
- 对账脚本 SHA-256：`{sha256(AUDIT / 'reconcile_current_tree.py')}`
- 原始 A8 的 `branch-inventory.csv`、`unmapped-reachable.csv` 和审计 README 保留为 382 项冻结锚点，没有覆盖。

## 当前映射和缺口

- 当前目录 ID 已全部映射：{len(mapped_ids)}/{len(catalog_ids)}。
- 当前仍有 {len(current_gaps)} 条标为玩家可达但尚未映射。
- 分支清单按字面有 {len(literal_reachable_without_id)} 条 `player_reachable=yes` 且没有独立 `catalog_id`；它们均有逐行归类说明，未计入当前未映射缺口。其中 {accepted_without_id} 条的 `outcome=accepted` 仅表示该源码分支可执行，不能单独证明它是独立游戏状态转移。
- 以本脚本生成的 {len(catalog_ids)} 项 overlay 为准；外部 triage 输入保留在 `current-tree-player-path-gaps.csv`，不是当前未映射清单。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave`、`world.window_focus_out`、`player.look_changed`、`player.movement` 与 `world.window_close_request` 已在对应测试中登记；无目标 E 输入复用 `world.raycast_unfocused`，成功 E 输入由 captured 鼠标模式的窗口测试走完整 Player→World 信号链。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`。吧台实体入口曾因缺少后置断言被列为弱证据；当前实体射线与 E 键集成测试已补足，映射到 `world.services_open`。试玩提示与 trace 文件 I/O 结果不改变权威状态，分别归为非状态转移；相关 I/O 错误注入未做专门测试。当前弱证据表有 {len(weak_evidence)} 行。
- `persistence_replay.rng_negative_control` 是测试侧人工扰动的负对照，现已从 `transitions` 移至 `verification_controls`；它仍作为正向重放断言的非空检查，但不再增加状态转移目录计数。
- 五条 `route_guard.cash_*` 历史 ID 与 `route_guard.cash_general` 共用 `routes.gd:49-50` 的同一拒绝后继；当前 overlay 将它们归并到该单一 ID，六条路线仍由同一专项逐项验证。
- 原 12 条世界/牌桌编排候选逐项复核后，实际状态后继归并到已有规则层 ID；纯 UI/调度包装早退标为 `not_a_transition`，不借用其他入口的 ID。没有因这些包装层新增语义 ID，也没有把当前目录宣称为完整分母；当前候选表无未映射行不等于证明不存在其他缺口，全球转移分母仍未冻结。
- 分支行 disposition 计数：`{dict(counts)}`。

## 限制

当前树对账把原 382 项审计映射到现行目录，并补入本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、窗口生命周期、玩家输入和世界/牌桌编排证据。函数级清点覆盖 {source_file_count} 个运行时文件、{function_count} 个函数（{function_counts.get('audit_inventory', 0)} 个在分支清单中，{function_counts.get('explicit_exclusion', 0)} 个明确排除，{function_counts.get('unclassified', 0)} 个未分类）；源码点位清点 {branch_site_count} 个 if/elif/match 行首位置（{branch_site_counts.get('branch_inventory_ref', 0)} 个有清单引用，{branch_site_counts.get('unclassified_branch_site', 0)} 个未分类）。这些数只证明函数/源码点位有归属，不代表分支结果穷尽。玩家路径分母和状态组合空间仍未冻结，因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

## 重建

在仓库根目录运行：

```sh
python3 docs/3d-production/external-handoff/A8-global-catalog-audit/reconcile_current_tree.py
python3 output/external-handoff/A8/build_a8.py --check
```

第二条命令只校验原始 382 项冻结锚点；它会把新增 ID 报作锚点漂移提示，这是预期行为。当前树归因以本脚本生成的当前目录 overlay 为准。
"""
    (AUDIT / "current-tree-reconciliation.md").write_text(text, encoding="utf-8")
    print(f"CURRENT_TREE ids={len(catalog_ids)}/{len(mapped_ids)} rows={len(branches)} gaps={len(current_gaps)} weak={len(weak_evidence)} disposition={dict(counts)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
