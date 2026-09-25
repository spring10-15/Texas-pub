#!/usr/bin/env python3
"""Build a current-tree overlay while preserving the frozen A8 audit files."""
from __future__ import annotations

import csv
import hashlib
import json
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
AUDIT = ROOT / "docs/3d-production/external-handoff/A8-global-catalog-audit"
CATALOG = ROOT / "docs/3d-production/phase-1/coverage/transitions.json"
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


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    catalog_ids = {row["id"] for row in catalog["transitions"]}
    branch_fields, branches = read_csv(AUDIT / "branch-inventory.csv")
    _, old_gaps = read_csv(AUDIT / "unmapped-reachable.csv")

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
    for row in current_gaps:
        if "20260925-103506" in row["evidence_report"] or "20260925-105659" in row["evidence_report"]:
            row["evidence_report"] = row["evidence_report"].replace("20260925-103506/report.json", LATEST_REPORT).replace("20260925-105659/report.json", LATEST_REPORT)

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

    for row in branches:
        source = ROOT / row["source_file"]
        if not source.is_file():
            raise SystemExit(f"Missing source file: {row['source_file']}")
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

    write_csv(AUDIT / "current-tree-branch-inventory.csv", branch_fields, branches)
    write_csv(AUDIT / "current-tree-unmapped-player-path-gaps.csv", branch_fields, current_gaps)
    write_csv(AUDIT / "current-tree-weak-evidence.csv", branch_fields, weak_evidence)
    counts = Counter(row["disposition"] for row in branches)
    # This is the source revision used by the regression and overlay. Later
    # documentation-only commits are allowed; verify_reconciliation.py checks
    # that game rules, runtime scripts, tests, and catalog stayed unchanged.
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report = ROOT / LATEST_REPORT
    lifecycle_report = ROOT / "output/3d/lifecycle-coverage.json"
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
- 以本脚本生成的 {len(catalog_ids)} 项 overlay 为准；外部 triage 输入保留在 `current-tree-player-path-gaps.csv`，不是当前未映射清单。
- `start.partial_bankroll`、`entry.heat_cap`、`settlement.heat_relief`、`poker.player_raise_pattern`、`run_variant.room_layout_selected`、`poker_blind.short_stack_posts`、`poker_progress.seeded_deal`、`world.autosave`、`world.window_focus_out`、`player.look_changed`、`player.movement` 与 `world.window_close_request` 已在对应测试中登记；无目标 E 输入复用 `world.raycast_unfocused`，成功 E 输入由 captured 鼠标模式的窗口测试走完整 Player→World 信号链。
- 原表 40 条候选中，34 条标为 `player_reachable=yes`，6 条标为 `no`；其中 1 条 yes 已有 `world.services_open` ID，但实体入口后置证据偏弱。当前树把 6 条 no 排除出玩家路径缺口，把该 services 行移入弱证据表；另 1 条仅显示试玩存档提示、不改变权威状态，也分类为非状态转移。
- 原 12 条世界/牌桌编排候选逐项复核后，实际状态后继归并到已有规则层 ID；纯 UI/调度包装早退标为 `not_a_transition`，不借用其他入口的 ID。没有新增语义 ID，也没有把 394 项目录宣称为完整分母；当前候选表无未映射行不等于证明不存在其他缺口，全球分母仍未冻结。弱证据行见 `current-tree-weak-evidence.csv`。
- 分支行 disposition 计数：`{dict(counts)}`。

## 限制

此对账仅把原 382 项审计映射到当前目录，并补入本金封顶、入座风声封顶、盈利降风声、玩家行为画像、房间图选择、窗口生命周期、玩家输入和世界/牌桌编排证据及明确的可达性/展示项分类。它没有重新审计全部 16 个源码文件，也没有穷举组合状态空间，因此不得据此声称全局覆盖率已知或 Phase 1 已通过。

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
