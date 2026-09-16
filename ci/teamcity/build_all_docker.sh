#!/usr/bin/env bash
# Runs ci/teamcity/build_omp_local.sh inside the same Docker image TeamCity
# uses for the "Build OMP" step, so you don't need the oneAPI toolchain
# installed on your host.
#
# Requires your Nexus credentials for the "delft3d-conan-dev" Conan remote to
# be exported beforehand (never hardcode them here or commit them):
#   export CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV=<your-nexus-username>
#   export CONAN_PASSWORD_DELFT3D_CONAN_DEV=<your-nexus-password>
#
# Also requires credentials for the containers.deltares.nl Harbor registry,
# exported beforehand (never hardcode them here or commit them):
#   export DOCKER_REGISTRY_USERNAME=<your-harbor-username>
#   export DOCKER_REGISTRY_PASSWORD=<your-harbor-password-or-robot-token>
#
# Usage: ./ci/teamcity/build_omp_docker.sh [build_type] [container_tag]
#   build_type:    Release (default) | Debug | RelWithDebInfo ...
#   container_tag: oneapi-2024 (default)

set -eo pipefail

if [[ -z "${CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV:-}" || -z "${CONAN_PASSWORD_DELFT3D_CONAN_DEV:-}" ]]; then
    echo "ERROR: CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV and CONAN_PASSWORD_DELFT3D_CONAN_DEV must be set." >&2
    echo "Export your Nexus credentials for the 'delft3d-conan-dev' remote before running this script." >&2
    exit 1
fi

if [[ -z "${DOCKER_REGISTRY_USERNAME:-}" || -z "${DOCKER_REGISTRY_PASSWORD:-}" ]]; then
    echo "ERROR: DOCKER_REGISTRY_USERNAME and DOCKER_REGISTRY_PASSWORD must be set." >&2
    echo "Export your containers.deltares.nl credentials before running this script." >&2
    exit 1
fi

BUILD_TYPE="${1:-Release}"
CONTAINER_TAG="${2:-oneapi-2024}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"


docker run --rm \
    --mount type=volume,source=swan-conan-cache,target=/conan-cache \
    -e CONAN_HOME=/conan-cache \
    -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV \
    -e CONAN_PASSWORD_DELFT3D_CONAN_DEV \
    -v "${REPO_ROOT}:/workspace" \
    -w /workspace \
    "containers.deltares.nl/swan-dev/delft3d-buildtools-linux:${CONTAINER_TAG}" \
    ./ci/teamcity/SWAN/linux/containers/scripts/build_all_local.sh "${BUILD_TYPE}"
