#!/usr/bin/env bash
#
# Phase 3 of the report, run locally with Docker instead of on the HPC facility
# with Singularity. See job.slurm for the Isambard/Slurm version.
#
# Mounts cipher/ read-only-in-memory at plain/, runs the analysis against the
# mount, and unmounts. All three happen inside a single container invocation:
# the FUSE mount exists only within that container process, so when the
# container exits the decrypted view ceases to exist.
#
# Usage:  ./03-mount-and-analyse.sh

set -euo pipefail

IMAGE=gocryptfs-example
DATASET=example.dta

cd "$(dirname "$0")"

if [ ! -e cipher/gocryptfs.conf ]; then
    echo "cipher/ is not initialised. Run ./02-encrypt.sh first." >&2
    exit 1
fi

# Create mount point
mkdir -p plain

# Mount, analyse, and unmount in a single container session
docker run --rm --privileged -v "$PWD":/work "$IMAGE" \
    bash -c "
        set -e
        gocryptfs -passfile /work/passphrase.txt /work/cipher /work/plain
        Rscript /work/analysis.R /work/plain/${DATASET} /work/results
        fusermount -u /work/plain
    "

echo
echo "The container has exited, so the FUSE mount no longer exists."
echo "plain/ on disk is empty:"
ls -A plain/ || true
