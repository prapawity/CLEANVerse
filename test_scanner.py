import os
import tempfile
import unittest
from pathlib import Path
from threading import Event
from scanner import scan, unchanged

class ScannerTests(unittest.TestCase):
    def test_duplicates_exclusions_and_changes(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'a').write_bytes(b'same'); (root/'b').write_bytes(b'same'); (root/'c').write_bytes(b'diff'); (root/'excluded').mkdir(); (root/'excluded'/'d').write_bytes(b'same')
            result=scan(root,[root/'excluded'])
            self.assertEqual(len(result.files),3)
            self.assertEqual({r.path.name for r in result.duplicates[0]},{'a','b'})
            rec=next(r for r in result.files if r.path.name=='a')
            self.assertTrue(unchanged(rec)); (root/'a').write_bytes(b'changed'); self.assertFalse(unchanged(rec))
    def test_cancelled(self):
        with tempfile.TemporaryDirectory() as tmp:
            e=Event(); e.set(); result=scan(Path(tmp),cancel=e)
            self.assertTrue(result.cancelled); self.assertEqual(result.files,[])
    def test_hardlinks_not_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); (root/'a').write_bytes(b'same')
            try: os.link(root/'a',root/'b')
            except OSError: self.skipTest('hardlinks unavailable')
            self.assertEqual(scan(root).duplicates,[])
    def test_invalid_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'file'; p.write_text('x')
            with self.assertRaises(ValueError): scan(p)
if __name__=='__main__': unittest.main()

