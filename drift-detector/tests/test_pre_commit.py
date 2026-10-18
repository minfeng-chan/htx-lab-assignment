"""Exercise the actual Git hook in a disposable repository."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class HookTests(unittest.TestCase):
    def test_staged_only_and_commit_blocking(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            def git(*args):
                return subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
            self.assertEqual(git("init", "-b", "main").returncode, 0)
            git("config", "user.name", "Hook test")
            git("config", "user.email", "hook-test@example.com")
            git("config", "core.hooksPath", ".githooks")
            (repo/".githooks").mkdir()
            shutil.copy2(ROOT/".githooks/pre-commit", repo/".githooks/pre-commit")
            (repo/"drift-detector").mkdir()
            for name in ("detector.py", "pre_commit.py"):
                shutil.copy2(ROOT/"drift-detector"/name, repo/"drift-detector"/name)
            (repo/"infra").mkdir()
            config = repo/"infra/main.tf"
            config.write_text('cidr_blocks = ["0.0.0.0/0"]\n')
            git("add", "infra/main.tf")
            blocked = git("commit", "-m", "Unsafe first commit")
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn("Commit blocked", blocked.stderr)
            self.assertTrue((repo/"reports/pre-commit-risk.json").is_file())
            config.write_text('description = "CSV ingestion"\n')
            git("add", "infra/main.tf")
            # Unsafe unstaged edits must not affect the safe staged commit.
            config.write_text('cidr_blocks = ["0.0.0.0/0"]\n')
            allowed = git("commit", "-m", "Safe staged content")
            self.assertEqual(allowed.returncode, 0, allowed.stdout + allowed.stderr)
            git("add", "infra/main.tf")
            blocked = git("commit", "-m", "Unsafe staged edit")
            self.assertNotEqual(blocked.returncode, 0)
            self.assertIn("Commit blocked", blocked.stderr)


if __name__ == "__main__":
    unittest.main()
