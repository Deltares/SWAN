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