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
    # -nosyslog: there is no syslog socket in the container, and without it
    # gocryptfs prints a delivery error for every message it tries to send
    gocryptfs -nosyslog -passfile passphrase.txt cipher plain
    # Under Apptainer the container root filesystem is read-only, so fusermount
    # cannot write its lock file and the unmount fails. That is harmless: the
    # mount lives in this container's mount namespace, so it is destroyed when
    # the container exits either way. Under Docker the unmount succeeds.
    trap 'fusermount -u plain 2>/dev/null || true' EXIT
    Rscript analysis.R plain/$DATASET results
"

echo
echo "The container has exited, so the FUSE mount no longer exists."
echo "plain/ on disk is empty:"
ls -A plain/ || true
