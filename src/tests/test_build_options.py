"""Verify matching dependency and compiler options for METIS builds."""
from contextlib import redirect_stdout
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
import build
import run_conan


class BuildOptionTests(unittest.TestCase):
    def test_build_defaults_and_overrides_reach_conan_and_cmake(self):
        cases = [([], False), (["--mpi"], True), (["--mpi", "--no-metis"], False),
                 (["--metis"], True), (["--mpi", "--metis"], True)]
        for flags, expected in cases:
            with self.subTest(flags=flags), \
                 patch.object(sys, "argv", ["build.py", "--keep-build", *flags]), \
                 patch.object(build.platform, "system", return_value="Linux"), \
                 patch.object(build, "run_conan") as conan, \
                 patch.object(build, "run_cmake_configure") as cmake, \
                 redirect_stdout(io.StringIO()):
                build.main()
                self.assertIs(conan.call_args.kwargs["with_metis"], expected)
                self.assertIs(cmake.call_args.kwargs["with_metis"], expected)

    def test_conan_wrapper_selects_optional_dependency(self):
        for enabled in (False, True):
            with self.subTest(enabled=enabled), \
                 patch.object(build.platform, "system", return_value="Windows"), \
                 patch.object(build.subprocess, "run") as run:
                build.run_conan(Path("build"), build_type="Release", with_metis=enabled)
                self.assertEqual("--with-metis" in run.call_args.args[0], enabled)

    def test_cmake_wrapper_selects_matching_build_option(self):
        with tempfile.TemporaryDirectory() as folder:
            for enabled in (False, True):
                with self.subTest(enabled=enabled), \
                     patch.object(build.platform, "system", return_value="Linux"), \
                     patch.object(build.subprocess, "run") as run:
                    build.run_cmake_configure(
                        vs_year=None, build_type="Release", build_dir=Path(folder),
                        install_dir=Path(folder) / "install", prl="ON", timing="OFF",
                        precision="", config_log="", with_metis=enabled
                    )
                    self.assertIn(f"-DUSE_METIS={'ON' if enabled else 'OFF'}", run.call_args.args[0])

    def test_every_windows_dependency_configuration_uses_same_option(self):
        for enabled in (False, True):
            with self.subTest(enabled=enabled), \
                 patch.object(run_conan.platform, "system", return_value="Windows"), \
                 patch.object(run_conan, "conan_install") as install:
                run_conan._do_install("profile", Path("build/conan"), "Release", with_metis=enabled)
                self.assertEqual(install.call_count, 3)
                self.assertTrue(all(call.kwargs["with_metis"] is enabled for call in install.call_args_list))

    def test_dependency_command_sets_consumer_option(self):
        for enabled in (False, True):
            with self.subTest(enabled=enabled), patch.object(run_conan.subprocess, "run") as run:
                run_conan.conan_install("profile", Path("build/conan"), "Release", with_metis=enabled)
                command = run.call_args.args[0]
                self.assertIn(f"&:with_metis={enabled}", command)


if __name__ == "__main__":
    unittest.main()
