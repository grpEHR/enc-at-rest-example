#!/usr/bin/env bash
#
# Copies the container image to an HPC facility without needing a registry
# account, for when `apptainer build --fakeroot` fails on the facility itself.
#
# Saves the Docker image as a tarball, copies it over, and converts it to a
# .sif there. The conversion only repacks layers that already exist, so unlike
# building from gocryptfs-example.def it needs no --fakeroot and works on a
# login node.
#
# The image must be built for the facility's architecture. Isambard nodes are
# Arm 64, which is what an Apple Silicon Mac produces by default; on an x86_64
# host, build with `docker build --platform linux/arm64` first.
#
# Usage:  ./09-transfer-image.sh [user@host] [remote directory]
#
# Defaults come from $ISAMBARD_HOST and $ISAMBARD_DIR, e.g.
#
#   export ISAMBARD_HOST=b35ck.3.isambard
#   export ISAMBARD_DIR=/projects/b35ck/enc-at-rest-example
#   ./09-transfer-image.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

HOST=${1:-${ISAMBARD_HOST:-}}
REMOTE_DIR=${2:-${ISAMBARD_DIR:-enc-at-rest-example}}

if [ -z "$HOST" ]; then
    echo "Usage: ./09-transfer-image.sh [user@host] [remote directory]" >&2
    echo "   or: export ISAMBARD_HOST=... ISAMBARD_DIR=..." >&2
    exit 1
fi

if [ "$RUNTIME" != docker ]; then
    echo "This script runs on the workstation that has Docker, not on the" >&2
    echo "facility. On the facility, use ./00-build.sh." >&2
    exit 1
fi

TAR=$IMAGE.tar

echo "Saving $IMAGE to $TAR ..."
docker save "$IMAGE" -o "$TAR"
ls -lh "$TAR"

echo
echo "Copying to $HOST:$REMOTE_DIR/ ..."
ssh "$HOST" "mkdir -p '$REMOTE_DIR'"
scp "$TAR" "$HOST:$REMOTE_DIR/"

echo
echo "Converting to $SIF on $HOST ..."
ssh "$HOST" "cd '$REMOTE_DIR' && apptainer build --force '$SIF' 'docker-archive://$TAR' && rm -f '$TAR'"

rm -f "$TAR"

echo
echo "Done. On $HOST:"
echo "    cd $REMOTE_DIR && make analyse"
