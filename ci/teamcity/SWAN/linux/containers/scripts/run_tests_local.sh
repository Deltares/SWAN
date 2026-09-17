#!/usr/bin/env bash

set -euo pipefail

readonly TESTBED_URL="https://repos.deltares.nl/repos/swan/testbed/trunk/"

if [[ $# -ne 3 ]]; then
	echo "Usage: $0 <testbed-folder> <test-version> <ref-version>" >&2
	exit 1
fi

if [[ -z "${SVN_USER_NAME:-}" || -z "${SVN_PASSWORD:-}" ]]; then
	echo "ERROR: SVN_USER_NAME and SVN_PASSWORD must be set." >&2
	exit 1
fi

echo "Starting test setup..."


TESTBED_FOLDER="$1"
TEST_VERSION="$2"
REF_VERSION="$3"
mkdir -p "${TESTBED_FOLDER}"

ORIGINAL_DIR="${PWD}"

cd "${TESTBED_FOLDER}"


if [[ -d "${TESTBED_FOLDER}/.svn" ]]; then
	svn update \
		--non-interactive \
		--no-auth-cache \
		--username "${SVN_USER_NAME}" \
		--password "${SVN_PASSWORD}" \
		"${TESTBED_FOLDER}"
else
	svn checkout \
		--non-interactive \
		--no-auth-cache \
		--username "${SVN_USER_NAME}" \
		--password "${SVN_PASSWORD}" \
		"${TESTBED_URL}" \
		"${TESTBED_FOLDER}"
fi

rm -rf .venv
uv venv --python 3.12
source .venv/bin/activate
pwd
ls -la .
uv pip install -r ./pip/lnx-requirements.txt


EXECUTABLE_DIR="/workspace/executables/swan/${TEST_VERSION}/lnx64"
ARCHIVE_NAME="swan_${TEST_VERSION}_lnx64.zip"
EXTRACTION_DIR="/tmp/swan_${TEST_VERSION}_lnx64"
mkdir -p "${EXECUTABLE_DIR}"
curl --fail --show-error --silent --location \
    --user "${CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV}:${CONAN_PASSWORD_DELFT3D_CONAN_DEV}" \
	"https://internal-artifacts.deltares.nl/repository/swan-dev/${TEST_VERSION}/lnx64/${ARCHIVE_NAME}" \
	--output "/tmp/${ARCHIVE_NAME}"
rm -rf "${EXTRACTION_DIR}"
mkdir -p "${EXTRACTION_DIR}"
unzip -q "/tmp/${ARCHIVE_NAME}" -d "${EXTRACTION_DIR}"
cp -a "${EXTRACTION_DIR}/swan_${TEST_VERSION}_lnx64/." "${EXECUTABLE_DIR}/"
rm -rf "/tmp/${ARCHIVE_NAME}" "${EXTRACTION_DIR}"


EXECUTABLE_DIR="/workspace/executables/swan/${REF_VERSION}/lnx64"
ARCHIVE_NAME="swan_${REF_VERSION}_lnx64.zip"
EXTRACTION_DIR="/tmp/swan_${REF_VERSION}_lnx64"
mkdir -p "${EXECUTABLE_DIR}"
curl --fail --show-error --silent --location \
    --user "${CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV}:${CONAN_PASSWORD_DELFT3D_CONAN_DEV}" \
	"https://internal-artifacts.deltares.nl/repository/swan-dev/${REF_VERSION}/lnx64/${ARCHIVE_NAME}" \
	--output "/tmp/${ARCHIVE_NAME}"
rm -rf "${EXTRACTION_DIR}"
mkdir -p "${EXTRACTION_DIR}"
unzip -q "/tmp/${ARCHIVE_NAME}" -d "${EXTRACTION_DIR}"
cp -a "${EXTRACTION_DIR}/swan_${REF_VERSION}_lnx64/." "${EXECUTABLE_DIR}/"
rm -rf "/tmp/${ARCHIVE_NAME}" "${EXTRACTION_DIR}"

LOG_FILE="run_testbench_${TEST_VERSION}_lnx64_OMP.log"

export OMP_NUM_THREADS=4
export NPROCESSES=1

.venv/bin/python run_testbench.py --prl omp --ref "${REF_VERSION}" --test "${TEST_VERSION}" --cases settings/templates/archive/two_swan_cases.inp >"${LOG_FILE}" 2>&1

export OMP_NUM_THREADS=1
export NPROCESSES=4

LOG_FILE_MPI="run_testbench_${TEST_VERSION}_lnx64_MPI.log"
.venv/bin/python run_testbench.py --prl mpi --ref "${REF_VERSION}" --test "${TEST_VERSION}" --cases settings/templates/MPI_DELTARES_swan_cases.inp >"${LOG_FILE_MPI}" 2>&1
echo "End Tests"

tail -n 100 "${LOG_FILE}"
tail -n 100 "${LOG_FILE_MPI}"

cd "${ORIGINAL_DIR}"
rm -rf test_results
mkdir -p test_results

cp -a "${TESTBED_FOLDER}/${LOG_FILE}" test_results/ 2>/dev/null || true
cp -a "${TESTBED_FOLDER}/${LOG_FILE_MPI}" test_results/ 2>/dev/null || true
cp -a "${TESTBED_FOLDER}/stat_output" test_results/ 2>/dev/null || true
