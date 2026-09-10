#!/usr/bin/env bash
#
# Phase 3 on Isambard, interactively: an alternative to 04-make-passfile.sh
# and job.slurm for short or exploratory analyses.
#
# Starts an interactive Slurm session, prompts for the passphrase at the
# terminal (so no passphrase file is ever written), mounts cipher/ at plain/
# and opens a shell inside the container. Exiting the shell unmounts the data.
#
# Usage:  ./05-interactive.sh [projectdir]
#
# Inside the shell, e.g.:  Rscript analysis.R plain/example.dta results

set -euo pipefail

PROJECTDIR=${1:-/projects/projectid}

# Pick up RUNTIME/SIF detection, but from the script's own directory
. "$(dirname "$0")/container.sh"

if [ "$RUNTIME" = docker ]; then
    echo "This script is for an HPC facility with Apptainer/Singularity." >&2
    echo "On a laptop with Docker, use ./03-mount-and-analyse.sh instead." >&2
    exit 1
fi

cd "$PROJECTDIR"
mkdir -p plain

srun --time=01:00:00 --pty \
  "$RUNTIME" exec --fakeroot --bind "$PWD" "$SIF" bash -c '
    set -euo pipefail
    ulimit -c 0                      # no core dumps of process memory
    gocryptfs cipher plain           # prompts for the passphrase
    trap "rm -rf plain/tmp; fusermount -u plain" EXIT
    mkdir -p plain/tmp               # temporary files encrypted too
    export TMPDIR="$PWD/plain/tmp" STATATMP="$PWD/plain/tmp"
    echo "Decrypted view at $PWD/plain - exit to unmount."
    bash -i
  '
