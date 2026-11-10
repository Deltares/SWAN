# Obstacle preparation regression

`SWMAIN` passes an empty array when no obstacles exist. The old explicit-size
`intent(out)` argument default-initialized one pointer component per grid face
before the no-obstacle guard, writing past that empty allocation. It also cleared
cached obstacle associations on later `COMPUTE` commands. An assumed-size
`intent(inout)` argument avoids those implicit writes and preserves the pointers.

The native test calls the production `SwanPrepComp` routine and checks that:

- A zero-length obstacle array does not modify surrounding pointer components.
- Previously found obstacle pointers survive repeated preparation calls when
  `OBSTDONE` skips rebuilding them.
- The zero-length allocation used by `SWMAIN` without obstacles is accepted.

A zero-length section backed by pointer guards detects the original overwrite
without relying on an allocator to report heap corruption. Zero vertices isolate
argument initialization from grid geometry.

Configure with `BUILD_TESTING=ON` (the default), build the test target, then
run with the same library search path used for the solver:

```sh
cmake --build build_omp --config Release --target swan_prep_comp_test
ctest --test-dir build_omp -C Release -R '^swan_prep_comp$' --output-on-failure
```

The test runs in a single process and does not initialize MPI or solve a wave
model. It fails against the original `dimension(nfaces), intent(out)` declaration
and passes with the assumed-size `intent(inout)` argument.

## Unstructured obstacle transport regression

`SwanCompUnstruc` must associate each stencil link with its face obstacle using
`=>`. Intrinsic assignment (`=`) copies obstacle data through the pointer
targets, dereferencing null pointers on faces without obstacles and on the
initially empty stencil links. The associations remain local to each OpenMP
thread; the obstacle data belongs to the shared obstacle list.

The OpenMP build also registers `swan_unstructured_obstacles`. This Python
standard-library test generates a 147-node Triangle mesh and constant depth,
then runs the solver with one and two threads. It checks normal completion,
finite positive wave heights, a transparent obstacle against the unobstructed
control, attenuation behind a transmitting obstacle, unchanged obstacle effects
on a second `COMPUTE`, and agreement across thread counts within 0.005 m. All
model files are temporary, and no external model data is required.

```text
cmake --build build_omp --config Release --target swan_omp swan_prep_comp_test
ctest --test-dir build_omp -C Release -R "^swan_(prep_comp|unstructured_obstacles)$" --output-on-failure
```

For an additional thread count, run the model test directly:

```text
python src/tests/prep/test_unstructured_obstacles.py path/to/swan_omp.exe --threads 1 2 8
```

Both Release and checked Debug executions fail with the old stencil pointer
assignments and pass with pointer association.

## History

This regression was introduced on 2026-09-16 by
[`fde37a3` - SWAN-293: use pointers (#16)](https://github.com/Deltares/swan/commit/fde37a3c2ca6f8e9001b0e580893171d9c6307c1).
That commit replaced integer `CROSS` entries with `OBSTDAT_PTR` wrappers whose
pointer components default to `NULL()`, while retaining the explicit-size
`intent(out)` argument in `SwanPrepComp`.

The caller's empty-array allocation already existed. The new default
initialization made entry to the routine write `nfaces` pointer components into
that empty allocation. The same initialization discarded cached obstacle pointers
on repeated preparation calls. This attribution was checked against the commit
diff and its parent.
