# Unstructured MPI solver port

This series ports the SWAN solver changes from Delft3D's
`swan-parallel-metis` branch at `a9a4e78926` onto standalone SWAN
`2a97069a5cd0611259d6d4d3aef9fb6962b18f78`. It also includes the subsequent
partition-list cleanup fix and its regression tests from the Delft3D working
tree. The standalone `.ftn`/`.ftn90` templates remain the source of truth.

## Included changes

- METIS partitioning of unstructured vertex graphs, halo exchanges,
  global boundary collection, resident-point output ownership, and
  stationary-wind sweep setup.
- Resettable boundary state and cleanup for repeated library calls.
- Full release of temporary cell, vertex, receive, and send lists, including
  partitions with no neighbors.
- Unstructured NetCDF hotstarts using global/local vertex maps, checked
  staging records, stream synchronization, and reusable record buffers.
- Consistent int16 spectral fill values and single-bin handling when reading
  missing spectral data.
- Chunked point-list spectral output without an additional full density
  copy. Map-grid reordering and the input array are retained.
- Reopening input units when a previous library call has closed or changed
  the saved file connection.

The build uses the existing Deltares METIS/GKlib Conan recipes with 32-bit
indices and reals. METIS C macros are excluded from Fortran compilation;
its `MSC` macro conflicts with SWAN's spectral-bin variable. The parallel
module compiles before its I/O consumers and is included in the solver
archive, avoiding a static-archive dependency cycle.

## Standalone compatibility

The port preserves `SWAN_LIB(COMM1)`, the caller-supplied communicator, and
the executable's ownership of MPI initialization/finalization. MPI and
OpenMP sources are generated through the existing `switch.py` conventions.

Newer standalone changes are retained, including obstacle pointer types,
the nautical-direction NetCDF interface, double-precision time values,
the positive time offset, FEWS swell output, and missing-depth handling.

## Scope retained in Delft3D

The following belong to Delft3D integration and are not solver code in this
repository:

- Delft3D-WAVE MDW parsing, unstructured-grid and ESMF mapping, flow/wave
  exchange, wave-map writing, and wrapper diagnostics.
- D-Flow FM wave-friction activation, missing-wave-data options, and flow
  NetCDF changes.
- Delft3D product build configuration, Docker changes, and coupled
  TestBench configuration.

These integration changes remain in the originating branch. Publishing a
SWAN package and updating Delft3D to consume it are separate tasks.

## Validation

Validation on Windows used Visual Studio 2022, Intel Fortran 2024.2, Intel
MPI 2021.13, and Release builds of both MPI and OpenMP configurations.

All three native MPI CTests pass: connected maps and halos, disconnected
partitions, and repeated setup/cleanup. The latter performs 32 warmups and
512 measured cycles, with growth below its 8 MiB allowance per rank.
See `src/tests/README.md` for commands and runtime setup.

Direct calls into the compiled spectral routines also passed:

- A scaled map with one missing bin preserves its 23 valid neighbors.
- A 4,101-point input reads all 24,606 bins correctly even when the old
  structured point-count value is deliberately different.
- Scaled and floating-point spectral writes cross the 4,096-point chunk
  boundary correctly. The scaled sentinel matches `_FillValue`, unscaled
  valid values are exact, and scaled error remains within half a quantization
  step.

Two existing standalone limitations were reproduced and remain outside this
port:

1. The small full-model unstructured smoke case reaches convergence and then
   exits with Windows heap corruption (`0xC0000374`). The pristine baseline
   at `2a97069` reproduces the same failure. Full-model output and hotstart
   round trips therefore are not certified by these checks.
2. A partly missing scaled output spectrum can lose valid bins because the
   existing scale-factor maximum includes positive `AGNC_DUMMY` values.
   That scale-factor calculation is unchanged by this port. The direct
   reader tests and complete-point missing-value writer tests above pass.

The independent code reviews checked all 13 solver source files changed by
the originating branch, the standalone-specific adaptations, module ordering,
METIS type widths, and the regression integration.
