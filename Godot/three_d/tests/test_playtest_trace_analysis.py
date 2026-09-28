import unittest

from analyze_playtest_trace import analyze_records


def opportunity(opportunity_id, options):
    return {"event": "decision_opportunity", "choice": opportunity_id, "details": {"options": options}}


def action(event, choice, opportunity_id, **details):
    return {"event": event, "choice": choice, "details": {"opportunity_id": opportunity_id, **details}}


class PlaytestTraceAnalysisTests(unittest.TestCase):
    def test_counts_opportunities_attempts_and_effective_decisions_separately(self):
        records = [
            opportunity("opp-start", [{"start_table": ""}, "leave_table"]),
            action("table_started", "cargo-table", "opp-start", collateral=""),
            opportunity("opp-1", ["fold", "call", "raise"]),
            action("decision_attempt_rejected", "check", "opp-1"),
            action("table_action", "call", "opp-1"),
            opportunity("opp-2", ["cancel"]),
            action("run_started", "smoky-den", "missing"),
        ]

        report = analyze_records(records)

        self.assertEqual(report["decision_opportunities"], 3)
        self.assertEqual(report["multi_option_opportunities"], 2)
        self.assertEqual(report["attempts_with_known_opportunity"], 3)
        self.assertEqual(report["effective_decisions"], 2)
        self.assertEqual(report["opportunities_without_attempt"], ["opp-2"])
        self.assertEqual(len(report["unclassifiable_actions"]), 1)

    def test_matches_service_choice_using_kind_item_and_target(self):
        records = [
            opportunity("opp-service", [
                {"kind": "intel", "id": "cargo-table", "target": ""},
                {"kind": "cool", "id": "", "target": ""},
            ]),
            action("service_action", "intel", "opp-service", item="cargo-table", target=""),
        ]

        report = analyze_records(records)

        self.assertEqual(report["effective_decisions"], 1)
        self.assertEqual(report["unmatched_choices"], [])

    def test_rejects_duplicate_opportunity_ids_and_unoffered_choices(self):
        records = [
            opportunity("opp-1", ["fold", "call"]),
            opportunity("opp-1", ["fold", "call"]),
            action("table_action", "raise", "opp-1"),
        ]

        report = analyze_records(records)

        self.assertEqual(report["duplicate_opportunity_ids"], ["opp-1"])
        self.assertEqual(len(report["unmatched_choices"]), 1)
        self.assertEqual(report["effective_decisions"], 0)


if __name__ == "__main__":
    unittest.main()
