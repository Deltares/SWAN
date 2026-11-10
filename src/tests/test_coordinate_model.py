"""Run translated curvilinear models through the actual SWAN input parser.

Pass one SWAN executable path. The test writes three temporary 3x3 models,
runs stationary wave computations, checks their significant wave heights,
and removes all temporary files. It covers translated grids and SERIES
coordinates with distinct file/component headers. Only the standard library is used.
"""

import argparse
import math
import os
from pathlib import Path
import subprocess
import tempfile


INPUT = """PROJECT 'coordinates' 'test'
SET NOR=90 DEPMIN=0.05 MAXERR=1 NAUT
MODE STAT
CGRID CURV 2 2 EXC 0 0 CIRCLE 36 0.04 1.0 24
READ COOR 1.0 'coordinates.dat' 4 0 0 FREE
INPGRID BOTTOM CURV 0 0 2 2
READINP BOTTOM 1.0 'depth.dat' 4 0 FREE
BOUN SHAPE JONSWAP 3.3 PEAK DSPR POWER
BOUN SEGM IJ 0 0 0 2 CON PAR 1.2 6.0 270.0 4.0
GEN3 KOMEN
OFF WINDG
OFF QUAD
NUM STOPC DABS=0.00001 DREL=0.00001 CURVAT=0.00001 NPNTS=100 STAT MXITST=20
TABLE 'COMPGRID' NOHEAD 'height.tbl' HSIGN
COMPUTE STAT
STOP
"""


def prepare_model(folder, origin_x, origin_y, series=False):
    """Write identical relative grid geometry at the requested origin."""
    folder.mkdir()
    xvalues = []
    yvalues = []
    for row in range(3):
        for column in range(3):
            xvalues.append(origin_x + 100.125 * column + 0.125 * row)
            yvalues.append(origin_y + 100.250 * row + 0.250 * column)
    xrecord = " ".join(format(value, ".17g") for value in xvalues) + "\n"
    yrecord = " ".join(format(value, ".17g") for value in yvalues) + "\n"
    model_input = INPUT
    if series:
        model_input = model_input.replace(
            "READ COOR 1.0 'coordinates.dat' 4 0 0 FREE",
            "READ COOR 1.0 SERIES 'coordinate_files.lst' 4 2 1 FREE",
        )
        # Each file has two file headers, followed by one component header.
        headers = "coordinate file\nfile metadata\ncoordinate component\n"
        (folder / "coordinates_x.dat").write_text(headers + xrecord, encoding="ascii")
        (folder / "coordinates_y.dat").write_text(headers + yrecord, encoding="ascii")
        (folder / "coordinate_files.lst").write_text(
            "coordinates_x.dat\ncoordinates_y.dat\n", encoding="ascii"
        )
    else:
        (folder / "coordinates.dat").write_text(xrecord + yrecord, encoding="ascii")
    (folder / "depth.dat").write_text(" ".join(["10.0"] * 9) + "\n", encoding="ascii")
    (folder / "INPUT").write_text(model_input, encoding="ascii")


def diagnostics(folder, screen_output):
    """Return concise SWAN output when a model check fails."""
    print_file = folder / "PRINT"
    print_output = print_file.read_text(encoding="utf-8", errors="replace") if print_file.exists() else ""
    return "\n".join((screen_output + "\n" + print_output).splitlines()[-50:])


def run_model(executable, folder):
    """Require successful execution and a physical, nonempty Hs table."""
    environment = os.environ.copy()
    environment["OMP_NUM_THREADS"] = "1"
    result = subprocess.run(
        [str(executable)], cwd=folder, env=environment,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", timeout=30,
    )
    details = diagnostics(folder, result.stdout)
    if result.returncode != 0:
        raise AssertionError(f"{folder.name}: SWAN exited with {result.returncode}\n{details}")
    if not (folder / "norm_end").is_file():
        raise AssertionError(f"{folder.name}: SWAN did not write norm_end\n{details}")
    height_table = folder / "height.tbl"
    if not height_table.is_file() or not height_table.stat().st_size:
        raise AssertionError(f"{folder.name}: no significant-wave-height table was written\n{details}")
    try:
        heights = [float(token.replace("D", "E").replace("d", "e"))
                   for token in height_table.read_text(encoding="ascii").split()]
    except ValueError as error:
        raise AssertionError(f"{folder.name}: wave-height table contains invalid values\n{details}") from error
    if len(heights) != 9:
        raise AssertionError(f"{folder.name}: expected 9 wave heights, got {len(heights)}\n{details}")
    if any(not math.isfinite(height) or height < 0.0 for height in heights):
        raise AssertionError(f"{folder.name}: nonfinite or negative wave heights: {heights}\n{details}")
    # COMPGRID tables advance X first; these are the three forced west nodes.
    if any(heights[index] <= 0.1 for index in (0, 3, 6)):
        raise AssertionError(f"{folder.name}: the forced boundary has no incoming waves: {heights}\n{details}")
    return heights


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path, help="Path to the SWAN executable to test")
    arguments = parser.parse_args()
    executable = arguments.executable.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="swan-coordinate-model-") as temporary:
        root = Path(temporary)
        original = root / "original"
        shifted = root / "shifted"
        series = root / "series"
        prepare_model(original, 100000000.125, 500000000.875)
        prepare_model(shifted, 1000.125, 2000.875)
        prepare_model(series, 100000000.125, 500000000.875, series=True)
        original_heights = run_model(executable, original)
        for variant in (shifted, series):
            variant_heights = run_model(executable, variant)
            for index, (first, second) in enumerate(zip(original_heights, variant_heights), 1):
                if not math.isclose(first, second, rel_tol=1.e-7, abs_tol=1.e-8):
                    raise AssertionError(
                        f"{variant.name} changed Hs at point {index}: {first} m versus {second} m"
                    )
    print("PASS SWAN coordinate translation and SERIES headers through full model input")


if __name__ == "__main__":
    main()
