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

## Optional METIS configuration

The original `!METIS` markers are restored. `switch.py -metis` activates them;
`!NMETIS` marks fallback code for builds without METIS. METIS is processed before
MPI so combined markers work in both configurations.

CMake's `USE_METIS` option defaults to `USE_MPI` on the first configure. With
`USE_METIS=OFF`, CMake does not find or link METIS, compile `SwanParallel`, or
register partition tests. OpenMP and structured MPI remain available. Unstructured
MPI partitioning requires `USE_METIS=ON` and reports that requirement if disabled.
Source generation tracks option changes, including reused build directories.

`build.py` accepts `--metis` and `--no-metis`; by default its setting follows
`--mpi`. It passes the same value to CMake and the Conan consumer's `with_metis`
option. A direct `run_conan.py install` omits METIS unless `--with-metis` is passed.
The lockfile retains pinned METIS/GKlib entries for enabled builds; disabled
installs do not include those packages in their dependency graph.

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

The optional configurations were rechecked with fresh Release builds for
MPI/METIS, OpenMP without METIS, and structured MPI without METIS. Their CTest
counts are 5, 2, and 2 respectively, including the source-switch and build-option
Python checks. Disabling METIS removes both METIS and GKlib from the Conan graph
and removes the METIS partition symbol from the solver archive. Reconfiguring an
existing OpenMP build with METIS on and then off updates both generated sources
and link inputs.

Fourteen full-model runs pass: connected/disconnected unstructured models,
MPI NetCDF restarts across one/two ranks, OpenMP NetCDF save/restart without
METIS, and structured OpenMP/MPI comparisons without METIS. Output coordinates
and six merged spectral files were checked. Unstructured MPI without METIS is
rejected with the `USE_METIS=ON` diagnostic and exit code 4. As described below,
these unstructured model checks apply the separate heap correction only to
temporary generated build files; the tracked MPI sources do not include it.

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

Scaled NetCDF output computes each point's scale factor from its valid bins.
The MPI regression checks that a spectrum with valid and missing bins retains
both the valid values within packing tolerance and the NetCDF fill codes.

The standalone heap corruption (`0xC0000374`) also affects pristine baseline
`2a97069`. It is fixed separately by `e473ebc` on the SWAN-329 heap-error branch.
Full-model validation of the optional build configurations used the obstacle
argument correction in temporary generated build sources.

The independent code reviews checked all 13 solver source files changed by
the originating branch, the standalone-specific adaptations, module ordering,
METIS type widths, and the regression integration.
