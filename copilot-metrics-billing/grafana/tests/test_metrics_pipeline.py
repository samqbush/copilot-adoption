import importlib.util
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock


GRAFANA = Path(__file__).resolve().parents[1]
BILLING = GRAFANA.parent
LOADER_PATH = GRAFANA / "scripts" / "load_metrics.py"
COLLECTOR_PATH = GRAFANA / "scripts" / "copilot-usage-metrics.sh"
SPEC = importlib.util.spec_from_file_location("load_metrics", LOADER_PATH)
LOAD_METRICS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LOAD_METRICS)


class RecordingCursor:
    def __init__(self):
        self.calls = []

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params=None):
        self.calls.append((statement, params))


class RecordingConnection:
    def __init__(self):
        self.recording_cursor = RecordingCursor()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def cursor(self):
        return self.recording_cursor

    def commit(self):
        pass


class RecordingPsycopg:
    def __init__(self):
        self.connection = RecordingConnection()

    def connect(self, database_url):
        return self.connection


class UsageRetentionTests(unittest.TestCase):
    def write_report(self, directory, report_type, rows, filename=None, metadata=None):
        path = Path(directory) / (filename or f"usage-{report_type}.json")
        report_meta = {
            "report_day": "2026-08-26",
            "future_metadata": "retained",
        }
        report_meta.update(metadata or {})
        path.write_text(
            json.dumps(
                {
                    "scope": "enterprise",
                    "slug": "example",
                    "report_type": report_type,
                    "day": "2026-08-26",
                    "report_meta": report_meta,
                    "report": rows,
                }
            ),
            encoding="utf-8",
        )
        return path

    def test_nonaggregate_report_is_retained_without_normalizing(self):
        with tempfile.TemporaryDirectory() as directory:
            self.write_report(
                directory,
                "users-1-day",
                [
                    {
                        "day": "2026-08-26",
                        "user_id": 42,
                        "future_metric": {"nested": True},
                    }
                ],
            )
            usage, _, reports, _, _ = LOAD_METRICS.collect_rows(
                directory, "run", "owner/repo", "example"
            )

        self.assertEqual(usage, [])
        snapshot = reports["snapshots"][0]
        self.assertEqual(snapshot["report"]["report_type"], "users-1-day")
        self.assertEqual(
            snapshot["report"]["report_meta"]["future_metadata"], "retained"
        )
        self.assertEqual(
            json.loads(snapshot["raw"][0]["raw"])["future_metric"], {"nested": True}
        )

    def test_rolling_raw_rows_use_snapshot_day_for_idempotent_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.write_report(
                directory,
                "users-28-day",
                [{"day": "2026-08-01", "user_id": 42}],
            )
            result = LOAD_METRICS.summarize_usage(str(path), "run", "owner/repo")

        self.assertEqual(result["report_record"]["day"], "2026-08-26")
        self.assertEqual(result["raw_records"][0]["day"], "2026-08-26")
        self.assertEqual(
            json.loads(result["raw_records"][0]["raw"])["day"], "2026-08-01"
        )

    def test_all_report_families_are_inventoried(self):
        with tempfile.TemporaryDirectory() as directory:
            for report_type in (
                "enterprise-1-day",
                "users-1-day",
                "user-teams-1-day",
                "repos-1-day",
            ):
                rows = [{"day": "2026-08-26", "future_field": report_type}]
                if report_type == "enterprise-1-day":
                    rows[0]["daily_active_users"] = 1
                self.write_report(directory, report_type, rows)

            usage, _, reports, _, _ = LOAD_METRICS.collect_rows(
                directory, "run", "owner/repo", "example"
            )

        self.assertEqual(len(usage), 1)
        self.assertEqual(len(reports["snapshots"]), 4)
        self.assertEqual(
            sum(len(snapshot["raw"]) for snapshot in reports["snapshots"]), 4
        )

    def test_differing_duplicate_snapshots_use_later_filename_everywhere(self):
        earlier = [
            {
                "day": "2026-08-26",
                "daily_active_users": 1,
                "totals_by_ide": [
                    {
                        "ide": "vscode",
                        "user_initiated_interaction_count": 1,
                    }
                ],
            }
        ]
        later = [
            {
                "day": "2026-08-26",
                "daily_active_users": 2,
                "totals_by_ide": [
                    {
                        "ide": "vscode",
                        "user_initiated_interaction_count": 2,
                    }
                ],
            }
        ]
        with tempfile.TemporaryDirectory() as directory:
            self.write_report(
                directory,
                "enterprise-1-day",
                earlier,
                filename="usage-a.json",
                metadata={"snapshot": "earlier"},
            )
            self.write_report(
                directory,
                "enterprise-1-day",
                later,
                filename="usage-z.json",
                metadata={"snapshot": "later"},
            )
            usage, breakdowns, reports, _, _ = LOAD_METRICS.collect_rows(
                directory, "run", "owner/repo", "example"
            )

        self.assertEqual(len(usage), 1)
        self.assertEqual(usage[0]["total_active_users"], 2)
        self.assertEqual(
            breakdowns["copilot_usage_ide"]["rows"][0][
                "user_initiated_interactions"
            ],
            2,
        )
        self.assertEqual(len(reports["snapshots"]), 1)
        snapshot = reports["snapshots"][0]
        self.assertEqual(snapshot["report"]["report_meta"]["snapshot"], "later")
        self.assertEqual(json.loads(snapshot["raw"][0]["raw"]), later[0])

    def test_identical_duplicate_snapshot_inserts_each_raw_hash_once(self):
        row = {"day": "2026-08-26", "user_id": 42}
        with tempfile.TemporaryDirectory() as directory:
            for filename in ("usage-a.json", "usage-z.json"):
                self.write_report(
                    directory, "users-1-day", [row], filename=filename
                )
            usage, breakdowns, reports, billing, scim_users = (
                LOAD_METRICS.collect_rows(
                    directory, "run", "owner/repo", "example"
                )
            )

        psycopg = RecordingPsycopg()
        LOAD_METRICS._load_to_postgres(
            psycopg,
            lambda value: value,
            "postgresql://example",
            usage,
            breakdowns,
            reports,
            billing,
            scim_users,
        )
        inserted = [
            params["row_hash"]
            for statement, params in psycopg.connection.recording_cursor.calls
            if statement == LOAD_METRICS.INSERT_USAGE_RAW
        ]
        self.assertEqual(len(inserted), 1)
        self.assertEqual(len(inserted), len(set(inserted)))

    def test_later_empty_snapshot_replaces_earlier_raw_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            self.write_report(
                directory,
                "users-1-day",
                [{"day": "2026-08-26", "user_id": 42}],
                filename="usage-a.json",
            )
            self.write_report(
                directory,
                "users-1-day",
                [],
                filename="usage-z.json",
            )
            usage, breakdowns, reports, billing, scim_users = LOAD_METRICS.collect_rows(
                directory, "run", "owner/repo", "example"
            )

        self.assertEqual(len(reports["snapshots"]), 1)
        self.assertEqual(reports["snapshots"][0]["report"]["report_rows"], 0)
        self.assertEqual(reports["snapshots"][0]["raw"], [])

        psycopg = RecordingPsycopg()
        LOAD_METRICS._load_to_postgres(
            psycopg,
            lambda value: value,
            "postgresql://example",
            usage,
            breakdowns,
            reports,
            billing,
            scim_users,
        )
        usage_statements = [
            statement
            for statement, _ in psycopg.connection.recording_cursor.calls
            if statement
            in (
                LOAD_METRICS.UPSERT_USAGE_REPORT,
                LOAD_METRICS.DELETE_USAGE_RAW,
                LOAD_METRICS.INSERT_USAGE_RAW,
            )
        ]
        self.assertEqual(
            usage_statements,
            [LOAD_METRICS.UPSERT_USAGE_REPORT, LOAD_METRICS.DELETE_USAGE_RAW],
        )

    def test_usage_report_database_writes_are_grouped_by_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            self.write_report(
                directory,
                "users-1-day",
                [{"day": "2026-08-26", "user_id": 42}],
            )
            self.write_report(
                directory,
                "repos-1-day",
                [{"day": "2026-08-26", "repository": "owner/repo"}],
            )
            usage, breakdowns, reports, billing, scim_users = (
                LOAD_METRICS.collect_rows(
                    directory, "run", "owner/repo", "example"
                )
            )

        psycopg = RecordingPsycopg()
        LOAD_METRICS._load_to_postgres(
            psycopg,
            lambda value: value,
            "postgresql://example",
            usage,
            breakdowns,
            reports,
            billing,
            scim_users,
        )
        usage_statements = [
            statement
            for statement, _ in psycopg.connection.recording_cursor.calls
            if statement
            in (
                LOAD_METRICS.UPSERT_USAGE_REPORT,
                LOAD_METRICS.DELETE_USAGE_RAW,
                LOAD_METRICS.INSERT_USAGE_RAW,
            )
        ]
        self.assertEqual(
            usage_statements,
            [
                LOAD_METRICS.UPSERT_USAGE_REPORT,
                LOAD_METRICS.DELETE_USAGE_RAW,
                LOAD_METRICS.INSERT_USAGE_RAW,
                LOAD_METRICS.UPSERT_USAGE_REPORT,
                LOAD_METRICS.DELETE_USAGE_RAW,
                LOAD_METRICS.INSERT_USAGE_RAW,
            ],
        )

    def test_documented_adoption_fields_are_normalized(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.write_report(
                directory,
                "enterprise-1-day",
                [
                    {
                        "day": "2026-08-26",
                        "daily_active_users": 3,
                        "totals_by_ai_adoption_phase": [
                            {
                                "phase": "Phase 1",
                                "phase_number": 1,
                                "total_engaged_users": 2,
                                "avg_pull_requests_minutes_to_review": 4.5,
                                "avg_pull_requests_review_cycles": 1.5,
                                "total_pull_requests_merged": 7,
                            }
                        ],
                    }
                ],
            )
            result = LOAD_METRICS.summarize_usage(str(path), "run", "owner/repo")

        adoption = result["breakdowns"]["copilot_usage_adoption_phase"][0]
        self.assertEqual(adoption["avg_pull_requests_minutes_to_review"], 4.5)
        self.assertEqual(adoption["avg_pull_requests_review_cycles"], 1.5)
        self.assertEqual(adoption["total_pull_requests_merged"], 7)

    def test_adoption_table_precedes_upgrade_columns(self):
        create_at = LOAD_METRICS.CREATE_SQL.index(
            "CREATE TABLE IF NOT EXISTS copilot_usage_adoption_phase"
        )
        alter_at = LOAD_METRICS.CREATE_SQL.index(
            "ALTER TABLE copilot_usage_adoption_phase"
        )
        self.assertLess(create_at, alter_at)


class UsageCollectorTests(unittest.TestCase):
    def make_curl(self, directory):
        curl = Path(directory) / "curl"
        curl.write_text(
            """#!/bin/sh
out=
url=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -w) shift 2 ;;
    http*) url=$1; shift ;;
    *) shift ;;
  esac
done
if echo "$url" | grep -q api.github.com; then
  printf '%s\\n' "$url" > "$REQUEST_LOG"
  case "$MOCK_MODE" in
    empty) : > "$out"; printf 204 ;;
    missing) printf '%s' '{"report_day":"2026-08-26"}' > "$out"; printf 200 ;;
    *)
      printf '%s' '{"report_day":"2026-08-26","download_links":["https://part/one","https://part/two"]}' > "$out"
      printf 200
      ;;
  esac
elif [ "$MOCK_MODE" = malformed ]; then
  printf 'not-json'
elif echo "$url" | grep -q /one; then
  printf '%s\\n' '{"day":"2026-08-26","part":1}'
else
  printf '%s' '{"day":"2026-08-26","part":2}'
fi
""",
            encoding="utf-8",
        )
        curl.chmod(0o755)
        return curl

    def run_collector(self, directory, *args, mode="success"):
        request_log = Path(directory) / "request.log"
        env = {
            **os.environ,
            "GH_TOKEN": "test-token",
            "PATH": f"{directory}:{os.environ['PATH']}",
            "REQUEST_LOG": str(request_log),
            "MOCK_MODE": mode,
        }
        result = subprocess.run(
            ["bash", str(COLLECTOR_PATH), "example", *args],
            capture_output=True,
            text=True,
            env=env,
        )
        return result, request_log

    def test_org_users_rolling_uses_documented_endpoint_and_handles_204(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_curl(directory)
            result, request_log = self.run_collector(
                directory, "--org", "--report-type", "users", "--28day", mode="empty"
            )
            requested_url = request_log.read_text(encoding="utf-8")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["report"], [])
        self.assertIn(
            "/orgs/example/copilot/metrics/reports/users-28-day/latest",
            requested_url,
        )

    def test_multipart_report_retains_every_row_and_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_curl(directory)
            result, _ = self.run_collector(
                directory,
                "--report-type",
                "repos",
                "--day",
                "2026-08-26",
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["report_type"], "repos-1-day")
        self.assertEqual([row["part"] for row in payload["report"]], [1, 2])
        self.assertEqual(payload["report_meta"]["report_day"], "2026-08-26")

    def test_unsupported_rolling_report_fails_before_request(self):
        with tempfile.TemporaryDirectory() as directory:
            self.make_curl(directory)
            result, request_log = self.run_collector(
                directory, "--report-type", "user-teams", "--28day"
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(request_log.exists())

    def test_missing_links_and_malformed_downloads_fail(self):
        for mode in ("missing", "malformed"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory:
                self.make_curl(directory)
                result, _ = self.run_collector(directory, mode=mode)
                self.assertNotEqual(result.returncode, 0)


class SynchronizedCollectorTests(unittest.TestCase):
    def test_collector_copies_only_differ_by_guide_reference(self):
        base = (BILLING / "scripts" / "copilot-usage-metrics.sh").read_text(
            encoding="utf-8"
        ).splitlines()
        grafana = COLLECTOR_PATH.read_text(encoding="utf-8").splitlines()
        base[2] = "# Guide: synchronized"
        grafana[2] = "# Guide: synchronized"
        self.assertEqual(base, grafana)


class SensitiveOutputTests(unittest.TestCase):
    def test_dry_run_withholds_input_values(self):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "usage-users.json"
            path.write_text(
                json.dumps(
                    {
                        "scope": "enterprise",
                        "slug": "PRIVATE_ENTERPRISE",
                        "report_type": "users-1-day",
                        "day": "2026-08-26",
                        "report": [
                            {
                                "day": "2026-08-26",
                                "user_login": "PRIVATE_USERNAME",
                            }
                        ],
                    }
                ),
                encoding="utf-8",
            )
            argv = ["load_metrics.py", "--data-dir", directory]
            with (
                mock.patch.object(sys, "argv", argv),
                mock.patch.dict(os.environ, {"DATABASE_URL": ""}),
                redirect_stdout(stdout),
                redirect_stderr(stderr),
            ):
                self.assertEqual(LOAD_METRICS.main(), 0)

        self.assertEqual(
            json.loads(stdout.getvalue()),
            {
                "status": "dry-run",
                "message": "Inputs parsed; no database writes performed.",
                "identifiable_data": "withheld",
            },
        )
        self.assertNotIn("PRIVATE_USERNAME", stdout.getvalue() + stderr.getvalue())
        self.assertNotIn("PRIVATE_ENTERPRISE", stdout.getvalue() + stderr.getvalue())

    def test_show_raw_is_rejected_before_inputs_are_parsed(self):
        stdout = io.StringIO()
        stderr = io.StringIO()
        argv = [
            "load_metrics.py",
            "--data-dir",
            "PRIVATE_PATH",
            "--show-raw",
        ]
        with mock.patch.object(sys, "argv", argv), redirect_stdout(stdout), redirect_stderr(stderr):
            self.assertEqual(LOAD_METRICS.main(), 2)

        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("--show-raw is disabled", stderr.getvalue())
        self.assertNotIn("PRIVATE_PATH", stderr.getvalue())


if __name__ == "__main__":
    unittest.main()
