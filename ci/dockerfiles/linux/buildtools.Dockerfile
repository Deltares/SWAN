ARG BASE_IMAGE_URL=containers.deltares.nl/swan-dev/delft3d-buildtools-linux:oneapi-2024

FROM ${BASE_IMAGE_URL} as buildtools

RUN dnf install -y zip && dnf clean all

