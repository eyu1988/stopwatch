#!/usr/bin/env python3
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def write_jsonl(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def session_rows(session_id, cwd, user, final=None, complete=None, turn_id="turn-1"):
    rows = [
        {
            "type": "session_meta",
            "payload": {"id": session_id, "cwd": cwd},
        },
        {
            "type": "event_msg",
            "payload": {"type": "user_message", "message": user, "text_elements": []},
        },
        {
            "type": "event_msg",
            "payload": {"type": "agent_message", "phase": "commentary", "message": "working"},
        },
    ]
    if final is not None:
        rows.append(
            {
                "type": "event_msg",
                "payload": {"type": "agent_message", "phase": "final_answer", "message": final},
            }
        )
    if complete is not None:
        rows.append(
            {
                "type": "event_msg",
                "payload": {
                    "type": "task_complete",
                    "turn_id": turn_id,
                    "last_agent_message": complete,
                },
            }
        )
    return rows


class StopwatchCodexTests(unittest.TestCase):
    def run_adapter(self, tmp, cwd, extra_env=None):
        env = os.environ.copy()
        env.update(
            {
                "CODEX_HOME": str(tmp / "codex-home"),
                "STOPWATCH_DIR": str(tmp / "timeline"),
                "STOPWATCH_TITLE": "testwatch",
                "STOPWATCH_TZ": "UTC",
                "STOPWATCH_CODEX_POLL_SECONDS": "0",
            }
        )
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            [sys.executable, str(ROOT / "adapter_codex.py"), "--cwd", str(cwd)],
            cwd=str(cwd),
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )

    def read_markdown(self, tmp):
        files = list((tmp / "timeline" / "codex").glob("*.md"))
        self.assertEqual(len(files), 1)
        return files[0].read_text(encoding="utf-8")

    def test_records_final_agent_message_before_task_complete_exists(self):
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            cwd = tmp / "project-a"
            cwd.mkdir()
            session = tmp / "codex-home" / "sessions" / "2026" / "06" / "17" / "rollout-a.jsonl"
            write_jsonl(
                session,
                session_rows("session-a", str(cwd), "question", final="final answer", complete=None),
            )

            result = self.run_adapter(tmp, cwd)

            self.assertEqual(result.returncode, 0, result.stderr)
            md = self.read_markdown(tmp)
            self.assertIn("project-a · question", md)
            self.assertIn("🤖 final answer", md)
            self.assertNotIn("🤖 working", md)

    def test_filters_latest_session_by_current_cwd(self):
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            cwd_a = tmp / "project-a"
            cwd_b = tmp / "project-b"
            cwd_a.mkdir()
            cwd_b.mkdir()
            root = tmp / "codex-home" / "sessions" / "2026" / "06" / "17"
            write_jsonl(
                root / "rollout-a.jsonl",
                session_rows("session-a", str(cwd_a), "right question", final="right answer"),
            )
            write_jsonl(
                root / "rollout-b.jsonl",
                session_rows("session-b", str(cwd_b), "wrong question", final="wrong answer"),
            )

            result = self.run_adapter(tmp, cwd_a)

            self.assertEqual(result.returncode, 0, result.stderr)
            md = self.read_markdown(tmp)
            self.assertIn("right question", md)
            self.assertIn("right answer", md)
            self.assertNotIn("wrong question", md)

    def test_deduplicates_same_turn(self):
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            cwd = tmp / "project-a"
            cwd.mkdir()
            session = tmp / "codex-home" / "sessions" / "2026" / "06" / "17" / "rollout-a.jsonl"
            write_jsonl(
                session,
                session_rows("session-a", str(cwd), "question", final="final answer", complete="final answer"),
            )

            first = self.run_adapter(tmp, cwd)
            second = self.run_adapter(tmp, cwd)

            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertEqual(second.returncode, 0, second.stderr)
            md = self.read_markdown(tmp)
            self.assertEqual(md.count("👤 question"), 1)


if __name__ == "__main__":
    unittest.main()
