import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("detector", Path(__file__).parents[1] / "detector.py")
detector = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(detector)


def diff(lines, path="infra/main.tf"):
    return f"diff --git a/{path} b/{path}\n--- a/{path}\n+++ b/{path}\n@@ -1 +1 @@\n{lines}\n"


class DetectorTests(unittest.TestCase):
    def high(self, text):
        self.assertGreater(detector.analyse(text)["summary"]["high"], 0)

    def test_assignment_fixture(self):
        self.high((Path(__file__).parents[1] / "fixtures/sample.diff").read_text())

    def test_ipv6(self):
        self.high(diff('+cidr_ipv6 = "::/0"'))

    def test_wildcard_iam(self):
        self.high(diff('+actions = ["*"]'))
        self.high(diff('+resources = ["*"]'))
        self.high(diff('+actions = ["s3:GetObject", "s3:*"]'))
        self.high(diff(' actions = [\n+ "s3:*",\n ]', 'infra/iam/policy.hcl'))

    def test_scoped_s3_prefix_not_wildcard_access(self):
        report = detector.analyse(diff('+resources = ["arn:aws:s3:::example/incoming/*"]', 'infra/iam/processor.hcl'))
        self.assertEqual(report["summary"]["high"], 0)
        self.assertEqual(report["summary"]["medium"], 1)

    def test_encryption_removal_and_disable(self):
        self.high(diff('-storage_encrypted = true'))
        self.high(diff('-storage_encrypted = true\n+storage_encrypted = false'))

    def test_network_acl(self):
        report = detector.analyse(diff('+from_port = 443', 'infra/network_acl.tf'))
        self.assertEqual(report["summary"]["medium"], 1)

    def test_public_toggle(self):
        self.high(diff('+publicly_accessible = true'))

    def test_empty_and_formatting(self):
        self.assertEqual(detector.analyse('')["findings"], [])
        self.assertEqual(detector.analyse(diff('-encrypt=true\n+encrypt = true'))["findings"], [])

    def test_low_description(self):
        report = detector.analyse(diff('+description = "CSV handoff bucket"'))
        self.assertEqual(report["summary"]["low"], 1)

    def test_malformed(self):
        with self.assertRaises(ValueError):
            detector.analyse('not a diff')

    def test_cli_exit_and_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'input.diff'
            output = Path(tmp) / 'report.json'
            for text, expected in [(diff('+actions = ["*"]'), 1), ('', 0), ('bad', 2)]:
                source.write_text(text)
                result = subprocess.run([sys.executable, SPEC.origin, '--diff', str(source), '--output', str(output)])
                self.assertEqual(result.returncode, expected)
                self.assertIn('findings', json.loads(output.read_text()))


if __name__ == '__main__':
    unittest.main()
