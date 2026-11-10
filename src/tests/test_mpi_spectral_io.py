"""Exercise SWAN's MPI NetCDF spectral collection and hotstart error paths."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


MODEL = """PROJECT 'mpi-spectral-io' '01'
MODE {mode} TWODIMENSIONAL
SET LEVEL 0.0
CGRID REGULAR 0.0 0.0 0.0 2000.0 600.0 20 6 CIRCLE {directions} 0.05 1.0 24
INPGRID BOTTOM REGULAR 0.0 0.0 0.0 20 6 100.0 100.0
READINP BOTTOM 1.0 'bottom.dep' 1 0 FREE
BOUND SHAPESPEC JONSWAP 3.3 PEAK DSPR DEGREES
BOUNDSPEC SIDE W CONSTANT PAR 1.0 5.0 270.0 30.0
WIND 10.0 270.0
GEN3 KOMEN
"""


def run_model(folder, command, mode, commands, directions=24, restart=None):
    """Run a small structured-grid model through SWAN's ordinary input path."""
    folder.mkdir()
    (folder / "bottom.dep").write_text("10.0\n" * (21 * 7), encoding="ascii")
    if restart is not None:
        shutil.copyfile(restart, folder / "initial.nc")
    model = MODEL.format(mode=mode, directions=directions)
    (folder / "INPUT").write_text(model + commands + "STOP\n", encoding="ascii")

    result = subprocess.run(
        command,
        cwd=folder,
        env=dict(os.environ, OMP_NUM_THREADS="1"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
        check=False,
    )
    (folder / "console.log").write_text(result.stdout, encoding="utf-8")
    errors = "\n".join(path.read_text(errors="replace") for path in folder.glob("Errfile*"))
    return result, errors


def assert_completed(folder, result, errors):
    if result.returncode or errors or not (folder / "norm_end").is_file():
        raise AssertionError(f"SWAN failed in {folder.name}: exit {result.returncode}\n{errors}\n{result.stdout}")


def check_repeated_spectra(work, command, inspect_records):
    folder = work / "collect"
    commands = (
        "SPEC 'COMPGRID' RELATIVE 'spectra.nc' OUTPUT 20000101.000000 1 HR\n"
        "SPEC 'COMPGRID' RELATIVE 'spectral-map.nc' ESCALE MDGRID OUTPUT 20000101.000000 1 HR\n"
        "COMPUTE STAT 20000101.000000\n"
        "COMPUTE STAT 20000101.010000\n"
    )
    result, errors = run_model(folder, command, "NONSTATIONARY", commands)
    assert_completed(folder, result, errors)
    subprocess.run([inspect_records, str(folder / "spectra.nc")], check=True)
    subprocess.run([inspect_records, str(folder / "spectral-map.nc")], check=True)


def check_hotstart(work, command):
    folder = work / "write_restart"
    result, errors = run_model(
        folder, command, "STATIONARY",
        "SPEC 'COMPGRID' RELATIVE 'spectra.nc'\n"
        "SPEC 'COMPGRID' RELATIVE 'spectral-map.nc' ESCALE MDGRID\n"
        "COMPUTE\n",
    )
    assert_completed(folder, result, errors)
    restart = folder / "spectra.nc"
    commands = "INITIAL HOTSTART SINGLE 'initial.nc' NETCDF\nCOMPUTE\n"
    valid = work / "valid_restart"
    result, errors = run_model(valid, command, "STATIONARY", commands, restart=restart)
    assert_completed(valid, result, errors)

    valid_map = work / "valid_map_restart"
    result, errors = run_model(valid_map, command, "STATIONARY", commands, restart=folder / "spectral-map.nc")
    assert_completed(valid_map, result, errors)

    invalid = work / "invalid_restart"
    result, errors = run_model(invalid, command, "STATIONARY", commands, directions=36, restart=restart)
    if result.returncode == 0 or "Number of directions in file does not match spectral grid" not in errors:
        raise AssertionError(f"Incompatible restart returned {result.returncode}\n{errors}\n{result.stdout}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case", choices=("collection", "hotstart"))
    parser.add_argument("inspect_records")
    parser.add_argument("launcher", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.launcher:
        parser.error("Pass the MPI launch command after the record checker.")
    with tempfile.TemporaryDirectory(prefix="swan_mpi_", dir=Path.cwd()) as folder:
        if args.case == "collection":
            check_repeated_spectra(Path(folder), args.launcher, args.inspect_records)
        else:
            check_hotstart(Path(folder), args.launcher)


if __name__ == "__main__":
    main()
