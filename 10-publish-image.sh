#!/usr/bin/env bash
#
# Publishes the container image to a registry, so that the facility can convert
# it with a plain `apptainer pull` -- no tarball to copy, and no --fakeroot.
#
# Builds for both linux/amd64 and linux/arm64, because Isambard nodes are Arm 64
# while most workstations are x86_64. On an Apple Silicon Mac the amd64 half is
# emulated and takes several minutes.
#
# Run `docker login` first.
#
# Usage:  ./10-publish-image.sh [user/repository[:tag]]
#
# The default comes from $DOCKERHUB_USER, e.g.
#
#   export DOCKERHUB_USER=myaccount
#   ./10-publish-image.sh                 # pushes myaccount/gocryptfs-example:latest

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

PLATFORMS=${PLATFORMS:-linux/amd64,linux/arm64}
BUILDER=${BUILDER:-$IMAGE-builder}

if [ -n "${1:-}" ]; then
    REF=$1
elif [ -n "${DOCKERHUB_USER:-}" ]; then
    REF=$DOCKERHUB_USER/$IMAGE:latest
else
    echo "Usage: ./10-publish-image.sh [user/repository[:tag]]" >&2
    echo "   or: export DOCKERHUB_USER=..." >&2
    exit 1
fi

if [ "$RUNTIME" != docker ]; then
    echo "This script needs Docker (buildx) to build and push the image." >&2
    exit 1
fi

# A multi-platform build needs the docker-container driver; the default builder
# on some Docker installations cannot do it. Creating it is idempotent.
docker buildx create --name "$BUILDER" --driver docker-container >/dev/null 2>&1 || true

echo "Building $REF for $PLATFORMS and pushing ..."
docker buildx build --builder "$BUILDER" --platform "$PLATFORMS" --push -t "$REF" .

echo
echo "Done. On the facility:"
echo "    apptainer pull $SIF docker://$REF"
echo "    make analyse"
