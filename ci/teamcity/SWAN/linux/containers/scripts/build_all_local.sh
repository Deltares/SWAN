#!/usr/bin/env bash
# Local equivalent of the "Build OMP" step in ci/teamcity/SWAN/linux/build.kt.
# Run this from inside the delft3d-buildtools-linux docker image (or a host
# with an equivalent toolchain: oneAPI + Conan + CMake).
#
# Requires your Nexus credentials for the "delft3d-conan-dev" Conan remote to
# be exported beforehand (never hardcode them here or commit them):
#   export CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=<your-nexus-username>
#   export CONAN_PASSWORD_DELFT3D_CONAN_DEV=<your-nexus-password>
#
# Usage: ./ci/teamcity/build_omp_local.sh [build_type]
#   build_type: Release (default) | Debug | RelWithDebInfo ...

set -eo pipefail

export REPOSITORY_PATH="${REPOSITORY_PATH:-/workspace}"
git config --global --add safe.directory "${REPOSITORY_PATH}"
export BRANCH_NAME="$(git -C "${REPOSITORY_PATH}" branch --show-current)"

if [[ -z "${CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV:-}" || -z "${CONAN_PASSWORD_DELFT3D_CONAN_DEV:-}" ]]; then
    echo "ERROR: CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV and CONAN_PASSWORD_DELFT3D_CONAN_DEV must be set." >&2
    echo "Export your Nexus credentials for the 'delft3d-conan-dev' remote before running this script." >&2
    exit 1
fi

BUILD_TYPE="${1:-Release}"

# Adjust/remove this if you're not using the oneAPI container environment.
source /etc/bashrc 2>/dev/null || true

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH}
export LD_LIBRARY_PATH=/usr/local/lib:${LD_LIBRARY_PATH}
export CMAKE_PREFIX_PATH=/usr/local:${CMAKE_PREFIX_PATH}
export CMAKE_INCLUDE_PATH=/usr/local/include:${CMAKE_INCLUDE_PATH}
export CMAKE_LIBRARY_PATH=/usr/local/lib:${CMAKE_LIBRARY_PATH}

export FC=mpiifx
export CXX=mpicxx # We would like to use mpiicpx, but some tests get different results
export CC=mpiicx

pwd
ls


# conan remote logout delft3d-conan-dev
# conan remote login delft3d-conan-dev "${CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV}" -p "${CONAN_PASSWORD_DELFT3D_CONAN_DEV}"

# Initialize Conan and install pre-built dependencies from Nexus
python run_conan.py initialize deltares --ci
python build.py --build --build-type "${BUILD_TYPE}" --ci
cp -rf build/install artifacts

python build.py --mpi --build --build-type "${BUILD_TYPE}" --ci
cp build/install/bin/swan_mpi.exe artifacts/bin

python build.py --timing --build --build-type "${BUILD_TYPE}" --ci
cp build/install/bin/swan_omp_timing.exe artifacts/bin

python build.py --double --build --build-type "${BUILD_TYPE}" --ci
cp build/install/bin/swan_omp_doubleprecision.exe artifacts/bin

echo "Current branch: ${BRANCH_NAME}"
ARCHIVE_NAME="swan_${BRANCH_NAME}_lnx64"
zip -r "build/${ARCHIVE_NAME}.zip" artifacts
zipnote "build/${ARCHIVE_NAME}.zip" \
    | sed "s|^@ artifacts\(.*\)$|@ artifacts\1\n@=${ARCHIVE_NAME}\1|" \
    | zipnote -w "build/${ARCHIVE_NAME}.zip"

NEXUS_ARTIFACT_URL="https://internal-artifacts.deltares.nl/repository/swan-dev/${BRANCH_NAME}/lnx64/${ARCHIVE_NAME}.zip"
curl --fail --show-error --silent \
    --user "${CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV}:${CONAN_PASSWORD_DELFT3D_CONAN_DEV}" \
    --upload-file "build/${ARCHIVE_NAME}.zip" \
    "${NEXUS_ARTIFACT_URL}"
