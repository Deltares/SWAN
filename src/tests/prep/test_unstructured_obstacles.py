"""Exercise obstacle discovery and cached links through a complete SWAN model.

Generate a small Triangle mesh, run transparent and transmitting obstacles,
and check repeated COMPUTE commands with one and two OpenMP threads. Only the
Python standard library is required; all model files are temporary.
"""

import argparse
import math
import os
from pathlib import Path
import subprocess
import tempfile


NX = 21
NY = 7
POINTS = NX * NY
HEIGHT_TOLERANCE = 0.005
INPUT = """PROJECT 'obstacle' 'test'
MODE STATIONARY TWODIMENSIONAL
SET LEVEL 0.0 NAUTICAL
CGRID UNSTRUCTURED CIRCLE 24 0.05 1.0 24
READGRID UNSTRUCTURED TRIANGLE 'grid'
INPGRID BOTTOM UNSTRUCTURED
READINP BOTTOM 1.0 'bottom.dep' 1 0 FREE
BOUND SHAPESPEC JONSWAP 3.3 PEAK DSPR DEGREES
BOUNDSPEC SIDE 1 CONSTANT PAR 1.0 5.0 270.0 30.0
GEN3 KOMEN
OFF WINDG
OFF QUAD
NUM STOPC DABS=0.0001 DREL=0.0001 CURVAT=0.0001 NPNTS=100 STAT MXITST=80
{obstacle}BLOCK 'COMPGRID' NOHEADER 'height.tbl' LAYOUT 3 HSIGN
{compute}STOP
"""


def prepare_model(folder, transmission, repeated):
    """Write a rectangular triangular grid, constant depth, and model input."""
    folder.mkdir()
    nodes = [f"{POINTS} 2 0 1"]
    for row in range(NY):
        for column in range(NX):
            node = row * NX + column + 1
            boundary = int(row in (0, NY - 1) or column in (0, NX - 1))
            nodes.append(f"{node} {100 * column} {100 * row} {boundary}")
    elements = [f"{2 * (NX - 1) * (NY - 1)} 3 0"]
    for row in range(NY - 1):
        for column in range(NX - 1):
            lower_left = row * NX + column + 1
            first = len(elements)
            elements.append(f"{first} {lower_left} {lower_left + 1} {lower_left + NX + 1}")
            elements.append(f"{first + 1} {lower_left} {lower_left + NX + 1} {lower_left + NX}")
    (folder / "grid.node").write_text("\n".join(nodes) + "\n", encoding="ascii")
    (folder / "grid.ele").write_text("\n".join(elements) + "\n", encoding="ascii")
    (folder / "bottom.dep").write_text("10.0\n" * POINTS, encoding="ascii")
    obstacle = ""
    if transmission is not None:
        obstacle = f"OBSTACLE TRANSM {transmission} LINE 950 5 950 595\n"
    compute = "COMPUTE\n" * (2 if repeated else 1)
    (folder / "INPUT").write_text(INPUT.format(obstacle=obstacle, compute=compute), encoding="ascii")


def diagnostics(folder, screen_output):
    """Keep both runtime errors and the final SWAN diagnostic lines."""
    print_path = folder / "PRINT"
    print_output = print_path.read_text(encoding="utf-8", errors="replace") if print_path.exists() else ""
    return "Screen:\n" + screen_output[-4000:] + "\nPRINT:\n" + print_output[-4000:]


def run_model(executable, folder, threads):
    """Require normal completion and a complete finite wave-height field."""
    environment = os.environ.copy()
    environment["OMP_NUM_THREADS"] = str(threads)
    try:
        result = subprocess.run(
            [str(executable)], cwd=folder, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=45,
        )
    except subprocess.TimeoutExpired as error:
        raise AssertionError(f"{folder.name}: SWAN timed out after 45 seconds") from error
    details = diagnostics(folder, result.stdout)
    if result.returncode != 0 or not (folder / "norm_end").is_file() or (folder / "Errfile").exists():
        raise AssertionError(f"{folder.name}: SWAN did not finish normally (exit {result.returncode})\n{details}")
    table = folder / "height.tbl"
    if not table.is_file():
        raise AssertionError(f"{folder.name}: no wave-height output\n{details}")
    try:
        values = [float(value.replace("D", "E").replace("d", "e"))
                  for value in table.read_text(encoding="ascii").split()]
    except ValueError as error:
        raise AssertionError(f"{folder.name}: invalid wave-height output\n{details}") from error
    if not values or len(values) % POINTS != 0:
        raise AssertionError(f"{folder.name}: incomplete wave-height field ({len(values)} values)\n{details}")
    heights = values[-POINTS:]
    if any(not math.isfinite(value) or value <= 0.0 for value in heights):
        raise AssertionError(f"{folder.name}: nonphysical wave height\n{details}")
    return heights


def require_matching(first, second, description):
    """Allow only differences below the model's wave-height tolerance."""
    difference = max(abs(a - b) for a, b in zip(first, second))
    if difference > HEIGHT_TOLERANCE:
        raise AssertionError(f"{description}: maximum Hs difference {difference:g} m exceeds {HEIGHT_TOLERANCE:g} m")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path, help="SWAN executable to test")
    parser.add_argument("--threads", type=int, nargs="+", default=[1, 2], help="OpenMP thread counts (default: 1 2)")
    arguments = parser.parse_args()
    if any(threads < 1 for threads in arguments.threads):
        parser.error("thread counts must be positive")
    executable = arguments.executable.resolve(strict=True)
    reference = None
    with tempfile.TemporaryDirectory(prefix="swan-obstacles-") as temporary:
        root = Path(temporary)
        for threads in arguments.threads:
            fields = {}
            for name, transmission, repeated in (
                ("no_obstacle", None, False), ("transparent", 1.0, False),
                ("transmitting", 0.5, False), ("repeated", 0.5, True),
            ):
                folder = root / f"{name}_{threads}"
                prepare_model(folder, transmission, repeated)
                fields[name] = run_model(executable, folder, threads)
            require_matching(fields["no_obstacle"], fields["transparent"], "Transparent obstacle changed waves")
            require_matching(fields["transmitting"], fields["repeated"], "Repeated COMPUTE changed cached obstacles")
            lee = [row * NX + column for row in (2, 3, 4) for column in (12, 13, 14)]
            baseline = sum(fields["no_obstacle"][point] for point in lee)
            transmitted = sum(fields["transmitting"][point] for point in lee)
            if transmitted >= 0.9 * baseline:
                raise AssertionError("The transmitting obstacle did not reduce Hs in its lee by at least 10%")
            if reference is None:
                reference = fields
            else:
                for name, heights in fields.items():
                    require_matching(reference[name], heights, f"{name}: OpenMP thread count changed waves")
            print(f"PASS unstructured obstacle discovery, transmission and repeated COMPUTE: {threads} threads")


if __name__ == "__main__":
    main()
