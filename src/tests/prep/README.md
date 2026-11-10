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
