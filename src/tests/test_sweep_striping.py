"""Check stationary wave heights on a gently turning grid with wind."""

import argparse
import math
import os
from pathlib import Path
import re
import subprocess
import tempfile


NX = 25
NY = 45
RESIDUAL_TOLERANCE = 0.012  # m
INPUT = """PROJECT 'sweep striping' 'test'
SET NOR=90 DEPMIN=0.05 MAXERR=1 NAUT
MODE STAT
CGRID CURV {mx} {my} CIRCLE 72 0.04 1.0 24
READ COOR 1.0 'coordinates.dat' 4 0 0 FREE
INPGRID BOTTOM CURV 0 0 {mx} {my}
READINP BOTTOM 1.0 'depth.dat' 4 0 FREE
WIND 16 85
BOUN SHAPE JONSWAP 3.3 PEAK DSPR POWER
BOUN SIDE EAST CON PAR 2.0 8.0 85.0 4.0
GEN3 KOMEN
BREAK CON 1.0 0.65
FRIC JON 0.038
NUM STOPC DABS={dabs} DREL={drel} CURVAT={curvat} NPNTS=100 STAT MXITST=50
TABLE 'COMPGRID' NOHEAD 'height.tbl' HSIGN
TEST ITEST=1
COMPUTE STAT
STOP
"""


def prepare_model(folder, dabs, drel, curvat):
    """Write an annular sector whose radial edges cross a spectral direction."""
    folder.mkdir()
    x_rows, y_rows, depth_rows = [], [], []
    for row in range(NY):
        angle = math.radians(8 * (row / (NY - 1) - 0.5))
        radius = [14000 + 35 * column for column in range(NX)]
        x_rows.append(" ".join(f"{r * math.cos(angle):.8f}" for r in radius))
        y_rows.append(" ".join(f"{r * math.sin(angle):.8f}" for r in radius))
        depth_rows.append(" ".join(f"{0.2 + 0.5 * col:.2f}" for col in range(NX)))
    (folder / "coordinates.dat").write_text("\n".join(x_rows + y_rows) + "\n", encoding="ascii")
    (folder / "depth.dat").write_text("\n".join(depth_rows) + "\n", encoding="ascii")
    (folder / "INPUT").write_text(
        INPUT.format(mx=NX-1, my=NY-1, dabs=dabs, drel=drel, curvat=curvat),
        encoding="ascii",
    )


def run_model(executable, folder, threads):
    """Run the model and return its grid-ordered significant wave heights."""
    environment = os.environ.copy()
    environment["OMP_NUM_THREADS"] = str(threads)
    result = subprocess.run(
        [str(executable)], cwd=folder, env=environment, timeout=120,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
        encoding="utf-8", errors="replace",
    )
    if result.returncode != 0 or not (folder / "norm_end").is_file():
        report = (folder / "PRINT").read_text(errors="replace") if (folder / "PRINT").exists() else ""
        raise AssertionError(f"SWAN did not finish\n{result.stdout[-4000:]}\n{report[-4000:]}")
    heights = [float(value) for value in (folder / "height.tbl").read_text().split()]
    if len(heights) != NX * NY or not all(math.isfinite(h) and h > 0.0 for h in heights):
        raise AssertionError("Expected one positive wave height for every node")
    return heights


def alongshore_residual(heights, row, column):
    """Return the height at a point relative to its alongshore neighbors."""
    index = row * NX + column
    return heights[index] - 0.5 * (heights[index - NX] + heights[index + NX])


def check_global_stop(folder):
    """Require a stop at the first global accuracy pass."""
    report = (folder / "PRINT").read_text(encoding="ascii")
    iterations = re.findall(r"(?m)^ *iteration +([0-9]+); sweep 4\b", report)
    accuracy = re.findall(r"accuracy OK in +([0-9.]+) %.*?\( *([0-9.]+) % required", report)
    reached = [float(actual) >= float(required) for actual, required in accuracy]
    if len(iterations) >= 50 or reached != [False] * (len(iterations) - 2) + [True]:
        raise AssertionError("Expected SWAN to stop at the first global accuracy pass")
    if "Unconverged near-tangent points" in report:
        raise AssertionError("Unexpected near-tangent diagnostic")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    args = parser.parse_args()
    executable = args.executable.resolve(strict=True)
    with tempfile.TemporaryDirectory(prefix="swan-sweep-") as temporary:
        root = Path(temporary)
        # Use a 1 mm Hs tolerance at all wet points to preserve the
        # spatial residual comparison with the tighter solve.
        prepare_model(root / "normal", dabs=0.001, drel=0.01, curvat=0.005)
        # Use a tighter solve to account for the grid's smooth physical gradients.
        prepare_model(root / "reference", dabs=0.00001, drel=0.00001, curvat=0.00001)
        normal = run_model(executable, root / "normal", threads=2)
        check_global_stop(root / "normal")
        reference = run_model(executable, root / "reference", threads=2)
        residual_error = max(
            abs(alongshore_residual(normal, row, column) -
                alongshore_residual(reference, row, column))
            for row in range(5, NY - 5) for column in range(1, NX - 1)
        )
        if residual_error > RESIDUAL_TOLERANCE:
            raise AssertionError(
                f"Alongshore wave-height residual error {residual_error:.5f} m "
                f"exceeds {RESIDUAL_TOLERANCE:.3f} m"
            )


if __name__ == "__main__":
    main()
