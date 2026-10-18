import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("selection", ROOT / ".github/scripts/select-units.py")
selection = importlib.util.module_from_spec(spec)
spec.loader.exec_module(selection)
APP = str(selection.APP)


class SelectionTests(unittest.TestCase):
    def test_s3_and_consumers(self):
        result = selection.select(ROOT, [APP + "/s3/batch-bucket/terragrunt.hcl"])
        self.assertEqual(set(result), {APP + suffix for suffix in ["/s3/batch-bucket", "/iam/batch-uploader", "/iam/csv-processor"]})
        self.assertLess(result.index(APP + "/s3/batch-bucket"), result.index(APP + "/iam/csv-processor"))

    def test_shared_environment(self):
        self.assertEqual(len(selection.select(ROOT, [APP + "/env.hcl"])), 11)

    def test_shared_root(self):
        self.assertEqual(len(selection.select(ROOT, ["infra/environments/root.hcl"])), 11)

    def test_module_change(self):
        self.assertEqual(len(selection.select(ROOT, ["infra/modules/direct-connect/main.tf"])), 11)

    def test_docs_and_prod_do_not_deploy_dev(self):
        self.assertEqual(selection.select(ROOT, ["infra/README.md", "infra/environments/prod/aws/account.hcl"]), [])

    def test_dependency_order(self):
        result = selection.select(ROOT, [APP + "/env.hcl"])
        self.assertLess(result.index(APP + "/vpc"), result.index(APP + "/eks"))
        self.assertLess(result.index(APP + "/rds"), result.index(APP + "/iam/csv-processor"))

    def test_removed_unit_blocks(self):
        with self.assertRaises(ValueError):
            selection.select(ROOT, [APP + "/removed/terragrunt.hcl"])


if __name__ == "__main__":
    unittest.main()
