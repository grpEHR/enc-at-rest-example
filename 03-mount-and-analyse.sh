#!/usr/bin/env bash
#
# Phase 3, run on whatever machine you are on: with Docker on a laptop, or with
# Apptainer/Singularity on an HPC login or compute node. See job.slurm for the
# Slurm batch version and 05-interactive.sh for the interactive one.
#
# Mounts cipher/ read-only-in-memory at plain/, runs the analysis against the
# mount, and unmounts. All three happen inside a single container invocation:
# the FUSE mount exists only within that container process, so when the
# container exits the decrypted view ceases to exist.
#
# Usage:  ./03-mount-and-analyse.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

require_cipher

DATASET=example.dta

# Create mount point
mkdir -p plain

# Mount, analyse, and unmount in a single container session
run_container --fuse -- bash -c "
    set -e
    gocryptfs -passfile passphrase.txt cipher plain
    trap 'fusermount -u plain' EXIT
    Rscript analysis.R plain/$DATASET results
"

echo
echo "The container has exited, so the FUSE mount no longer exists."
echo "plain/ on disk is empty:"
ls -A plain/ || true
