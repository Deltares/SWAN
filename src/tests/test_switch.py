"""Exercise source switches through the actual generator command."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SWITCH = Path(__file__).resolve().parents[1] / "switch.py"


class SourceSwitchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "src"
        self.source.mkdir()
        self.build = self.root / "build"
        self.template = (
            "!METIS    use SwanParallel\n"
            "!NMETIS    call serial_setup()\n"
            "!METIS!MPI    call mpi_exchange()\n"
            "!NMETIS!MPI    call structured_exchange()\n"
        )
        (self.source / "sample.ftn90").write_text(self.template, encoding="ascii")
        (self.source / "fixed.ftn").write_text(
            "!METIS      CALL PARTITION\n!METIS     & (LOGCOM)\n", encoding="ascii"
        )

    def generate(self, *flags):
        subprocess.run(
            [sys.executable, str(SWITCH), f"buildir={self.build}", *flags],
            cwd=self.source, check=True, capture_output=True, text=True
        )
        return (self.build / "generated" / "sample.f90").read_text(encoding="ascii")

    def test_metis_is_disabled_by_default(self):
        generated = self.generate()
        self.assertIn("!METIS    use SwanParallel\n", generated)
        self.assertIn("\n    call serial_setup()\n", generated)

    def test_metis_enables_fixed_and_free_form_lines(self):
        generated = self.generate("-metis")
        self.assertTrue(generated.startswith("    use SwanParallel\n"))
        self.assertIn("!NMETIS    call serial_setup()\n", generated)
        self.assertEqual(
            (self.build / "generated" / "fixed.for").read_text(encoding="ascii"),
            "      CALL PARTITION\n     & (LOGCOM)\n"
        )

    def test_nested_metis_mpi_switches(self):
        for metis in (False, True):
            for mpi in (False, True):
                with self.subTest(metis=metis, mpi=mpi):
                    flags = (['-metis'] if metis else []) + (['-mpi'] if mpi else [])
                    lines = self.generate(*flags).splitlines()
                    self.assertEqual("    call mpi_exchange()" in lines, metis and mpi)
                    self.assertEqual("    call structured_exchange()" in lines, not metis and mpi)

    def test_switch_changes_regenerate_unchanged_templates(self):
        template = self.source / "sample.ftn90"
        original_mtime = template.stat().st_mtime_ns
        enabled = self.generate("-metis", "-mpi")
        disabled = self.generate("-mpi")
        restored = self.generate("-metis", "-mpi")
        self.assertNotEqual(enabled, disabled)
        self.assertEqual(enabled, restored)
        self.assertEqual(template.stat().st_mtime_ns, original_mtime)

    def test_unchanged_switches_do_not_rewrite_generated_sources(self):
        self.generate("-metis")
        generated = self.build / "generated" / "sample.f90"
        old_time = max(generated.stat().st_mtime, SWITCH.stat().st_mtime) + 10
        os.utime(generated, (old_time, old_time))
        previous = generated.stat().st_mtime_ns
        self.generate("-metis")
        self.assertEqual(generated.stat().st_mtime_ns, previous)


if __name__ == "__main__":
    unittest.main()
