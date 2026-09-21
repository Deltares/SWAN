set -eo pipefail


TEST_VERSION="${1:-}"
REF_VERSION="${2:-41.51.9CONAN}"
REPO_ROOT="${3:-$(pwd)}"

CONTAINER_TAG="oneapi-2024"

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker run --rm \
    -e SVN_USER_NAME \
    -e SVN_PASSWORD \
    -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV \
    -e CONAN_PASSWORD_DELFT3D_CONAN_DEV \
    -v "${REPO_ROOT}:/workspace" \
    -v "${SCRIPT_ROOT}:/scripts" \
    -w /workspace \
    "containers.deltares.nl/swan-dev/swan-buildtools-linux:${CONTAINER_TAG}" \
    "/scripts/SWAN/linux/containers/scripts/run_tests_local.sh" "/workspace" "${TEST_VERSION}" "${REF_VERSION}"