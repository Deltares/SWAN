# Structured coordinate input regression tests

SWAN reads formatted and NetCDF structured-grid coordinates in double precision,
subtracts its double-precision origin, and then stores local coordinates in the
existing default-REAL solver arrays. The localization flag is reset by SWINIT
and prevents SWDIM from subtracting the origin or missing-value offsets twice.
Legacy unformatted coordinate records remain default REAL; scaling is applied
in double precision after reading those records.

Configure with BUILD_TESTING=ON, then build the executable and test program:

```text
cmake --build <build> --config Release --target swan_omp swan_coordinate_test
ctest --test-dir <build> -C Release -R "^swan_coordinate_" --output-on-failure
```

Use the normal SWAN runtime DLL or shared-library search paths when running.
The reader test covers all six layouts, free/fixed formatting, headers,
scaling, binary compatibility, NetCDF double metadata and missing values,
existing origins, invalid file units, missing-coordinate pairs, and resets.
The Python integration test runs two small stationary curvilinear models
through the actual executable and compares translated-coordinate wave heights.
Its input and output files are created in temporary directories and removed
after the test.
## Fortran coding profile and compatibility

The coordinate module uses named kinds, restricted imports, explicit legacy
interfaces, Doxygen argument documentation, and checked file operations. New
reader errors return through SWAN's diagnostic and layout-status conventions.
The Fortran test reports assertion failures and terminates only in its main
program. Exact comparisons in the regressions intentionally check representation
and translation invariance.

The source remains a `.ftn90` template because SWAN generates its compiled `.f90`
files with `switch.py`. Existing fixed-form templates and public legacy symbols
retain their formats and names. The existing NetCDF error handler is reused.
`SWAN_REAL_KIND = kind(0.0)` deliberately queries the compiler's default REAL
kind so the existing single/double build modes and binary records keep their ABI;
the unsuffixed literal is used only for that inquiry. `SWAN_COORD_KIND` is
`real64`. Reader and fixture units remain positive where SWAN's `FOR`/`INAR2D`
allocator contract requires it; unrelated file cleanup uses `newunit`.
