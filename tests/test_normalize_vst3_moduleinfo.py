import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import normalize_vst3_moduleinfo as normalizer

A = "ABCDEF019182FAEB536B4175536B536E"
B = "ABCDEF011234ABCD536B4175536B536E"


class ModuleInfoTests(unittest.TestCase):
    def do_normalize(self, source, expected="Skell-Snap"):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "moduleinfo.json"
            p.write_text(source, encoding="utf-8")
            changed = normalizer.normalize(p, expected)
            output = p.read_text(encoding="utf-8")
            return changed, json.loads(output), output

    def test_juce_trailing_commas(self):
        source = ('{"Name":"Skell-Snap","Version":"0.1.0",'
                  '"Classes":[{"CID":"%s","Snapshots":["x",],},'
                  '{"CID":"%s",},],}' % (A, B))
        with self.assertRaises(json.JSONDecodeError):
            json.loads(source)
        changed, data, strict = self.do_normalize(source)
        self.assertTrue(changed)
        self.assertEqual([x["CID"] for x in data["Classes"]], [A, B])
        self.assertEqual(data["Classes"][0]["Snapshots"], ["x"])
        self.assertNotIn(",}", strict)
        self.assertNotIn(",]", strict)

    def test_preserves_quoted_commas_and_escapes(self):
        source = ('{"Name":"Skell-Snap","Version":"0.1.0",'
                  '"Note":"literal ,} and ,] with \\"quotes\\"",'
                  '"Classes":[{"CID":"%s",}],}' % A)
        _, data, _ = self.do_normalize(source)
        self.assertEqual(data["Note"], 'literal ,} and ,] with "quotes"')

    def test_idempotent(self):
        source = ('{"Name":"Skell-Snap","Version":"0.1.0",'
                  '"Classes":[{"CID":"%s",}]}' % A)
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "moduleinfo.json"
            p.write_text(source, encoding="utf-8")
            self.assertTrue(normalizer.normalize(p, "Skell-Snap"))
            after = p.read_bytes()
            self.assertFalse(normalizer.normalize(p, "Skell-Snap"))
            self.assertEqual(after, p.read_bytes())

    def test_rejects_other_malformed_json(self):
        source = ('{"Name":"Skell-Snap","Version":"0.1.0" '
                  '"Classes":[{"CID":"%s"}]}' % A)
        with self.assertRaises(json.JSONDecodeError):
            self.do_normalize(source)

    def test_rejects_duplicate_classes(self):
        source = ('{"Name":"Skell-Snap","Version":"0.1.0",'
                  '"Classes":[{"CID":"%s"},{"CID":"%s"}]}' % (A, A.lower()))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.do_normalize(source)

    def test_rejects_wrong_identity_and_cid(self):
        source = ('{"Name":"Skell-Snap","Version":"0.1.0",'
                  '"Classes":[{"CID":"%s"}]}' % A)
        with self.assertRaisesRegex(ValueError, "name"):
            self.do_normalize(source, "Wrong Name")
        with self.assertRaisesRegex(ValueError, "CID"):
            self.do_normalize(source.replace(A, "bad"))


if __name__ == "__main__":
    unittest.main()
