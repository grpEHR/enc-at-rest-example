#!/usr/bin/env bash
#
# Builds the container image with whichever runtime is available: a Docker
# image with Docker, or a .sif with Apptainer/Singularity.
#
# Usage:  ./00-build.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

if [ "$RUNTIME" = docker ]; then
    docker build -t "$IMAGE" .
    echo
    echo "Built Docker image $IMAGE."
else
    # Apptainer unpacks the base image into a temporary directory and caches
    # the layers. Both default to $HOME, which on an HPC facility is usually
    # small and quota'd, so point them at the project directory instead.
    : "${APPTAINER_TMPDIR:=$PWD/.apptainer-tmp}"
    : "${APPTAINER_CACHEDIR:=$PWD/.apptainer-cache}"
    export APPTAINER_TMPDIR APPTAINER_CACHEDIR
    export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"
    export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
    mkdir -p "$APPTAINER_TMPDIR" "$APPTAINER_CACHEDIR"

    "$RUNTIME" build --fakeroot "$SIF" gocryptfs-example.def

    echo
    echo "Built $SIF."
fi
