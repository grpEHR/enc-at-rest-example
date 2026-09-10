#!/usr/bin/env bash
#
# Builds the container image with whichever runtime is available: a Docker
# image with Docker, or a .sif with Apptainer/Singularity.
#
# Given a registry reference, fetches that published image instead of building
# from source. This is the quickest route on a facility where `apptainer build
# --fakeroot` fails, because a pull needs no fakeroot at all.
#
# Usage:  ./00-build.sh [user/repository[:tag]]

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

REF=${1:-${IMAGE_REF:-}}

if [ -n "$REF" ]; then
    if [ "$RUNTIME" = docker ]; then
        docker pull "$REF"
        docker tag "$REF" "$IMAGE"
        echo
        echo "Pulled $REF and tagged it $IMAGE."
    else
        "$RUNTIME" pull --force "$SIF" "docker://$REF"
        echo
        echo "Pulled $REF into $SIF."
    fi
    exit 0
fi

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
