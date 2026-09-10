#!/bin/bash
#SBATCH --job-name=analysis
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --mem=16G
#
# Phase 3 on Isambard, as a batch job. Run both of these from the project
# directory -- the one holding cipher/, analysis.R and the .sif:
#
#   ./04-make-passfile.sh    # prompts, writes .passfile
#   sbatch job.slurm
#
# Slurm starts the job in the directory sbatch was invoked from, so there is
# nothing to configure in this file.
#
# Mount, analyse and unmount all happen inside a SINGLE container invocation:
# the FUSE mount exists only within that container's process namespace, so if
# the container exits -- at the end of the job or because of an error -- the
# mount is destroyed and no later process can reach the decrypted data.

set -euo pipefail
ulimit -c 0                        # no core dumps of process memory

SIF=gocryptfs-example.sif
DATASET=example.dta

RUNTIME=$(command -v apptainer >/dev/null && echo apptainer || echo singularity)

# The image has no locales installed and Apptainer passes the host environment
# through, so tell R not to try to set them
export APPTAINERENV_LC_ALL=C APPTAINERENV_LANG=C
export SINGULARITYENV_LC_ALL=C SINGULARITYENV_LANG=C

for f in "$SIF" cipher/gocryptfs.conf .passfile; do
    [ -e "$f" ] || { echo "$PWD/$f not found - submit from the project directory" >&2; exit 1; }
done

trap 'rm -f .passfile' EXIT        # fallback removal of passphrase
mkdir -p plain results

"$RUNTIME" exec --fakeroot --bind "$PWD" "$SIF" \
  bash -c '
    set -euo pipefail
    exec 3< .passfile              # open the passphrase file ...
    rm -f .passfile                # ... and remove it before use
    gocryptfs -nosyslog -passfile /dev/fd/3 cipher plain
    exec 3<&-
    trap "rm -rf plain/tmp; fusermount -u plain 2>/dev/null || true" EXIT
    mkdir -p plain/tmp             # temporary files encrypted too
    export TMPDIR="$PWD/plain/tmp" STATATMP="$PWD/plain/tmp"
    Rscript analysis.R plain/'"$DATASET"' results
  '
