# SWAN partition regression tests

Configure a build that includes the SWAN library with `USE_MPI=ON`, `USE_METIS=ON`,
and `BUILD_TESTING=ON`.
The tests link the actual library and call `SwanCommAdmin`, `SwanUvExchgI`,
and `SwanUvExchgR`; they do not reproduce the partition implementation.
The partition ownership is prescribed so mesh and halo assertions are
deterministic. Two MPI ranks use a communicator with reversed rank ordering
to exercise the library communicator independently of `MPI_COMM_WORLD`.

The CTest cases are:

- `swan_partition_connected`: checks local/global vertex maps, cell
  connectivity, resident/ghost flags, boundary markers, and integer/real
  halo exchanges across a shared boundary.
- `swan_partition_disconnected`: checks two independent triangular
  components, empty communication lists, and zero-neighbor halo calls.
- `swan_partition_repeated`: performs 32 warmup setup/cleanup cycles, then
  measures process-memory growth across 512 cycles on a mesh containing
  576 vertices and 1,008 triangles. Each cycle also checks markers and
  integer/real halo values. Growth must remain at or below 8 MiB per rank.
  The allowance accommodates allocator and MPI runtime variation while
  detecting retained partition-list nodes.

The C helper measures committed private process bytes on Windows using
`GetProcessMemoryInfo`, or resident process bytes on Linux using
`/proc/self/statm`. All ranks first agree whether measurement is available.
If any rank cannot measure, the repeated-memory test exits with CTest skip
code 77 on every rank. The connected and disconnected tests still run.

Build and run the tests using the configured build directory:

```text
cmake --build <build> --config Release --target swan_partition_test
ctest --test-dir <build> -C Release -R "^swan_partition_" --output-on-failure
```

On Windows, configure `MPIEXEC_PREFLAGS=-localonly` when using Intel MPI
locally. CMake resolves the MPI launcher from the configured MPI installation
instead of selecting another launcher from `PATH`. Ensure `PATH` contains
the Intel MPI runtime and the NetCDF/Conan dependency DLL directories, as for
the normal SWAN executables. On Linux, CMake uses the launcher and flags from
`FindMPI`; supply any host or scheduler options through `MPIEXEC_PREFLAGS`.

## Optional METIS checks

`USE_METIS` defaults to `USE_MPI` on the first CMake configure. Set it explicitly
when reusing a build directory. For example, use `-DUSE_MPI=ON -DUSE_METIS=ON`
for unstructured MPI partitioning, or `-DUSE_MPI=OFF -DUSE_METIS=OFF` for OpenMP
without METIS or GKlib. Structured MPI remains available with `USE_METIS=OFF`.

Both builds register `swan_source_switches` and `swan_build_options`. These run
standard-library Python regressions for fixed/free-form source generation,
combined METIS/MPI switches, option changes without template changes, and matching
Conan/CMake settings. Partition tests are registered only when both MPI and METIS
are enabled.

```text
ctest --test-dir <build> -C Release --output-on-failure
```

The build wrapper follows `--mpi` when `--metis` is unspecified. Use
`python build.py --mpi --no-metis` to select structured MPI without METIS, or
`python build.py --no-metis` for OpenMP without METIS. Direct Conan installs use
`-o "&:with_metis=True"` or `-o "&:with_metis=False"`; `run_conan.py install`
provides `--with-metis` and defaults to dependencies without METIS. Keep that
setting consistent with CMake's `USE_METIS` option. The shared lockfile pins both
dependency sets.
