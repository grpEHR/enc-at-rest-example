#!/bin/bash
#SBATCH --job-name=analysis
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --mem=16G
set -euo pipefail
ulimit -c 0                        # no core dumps of process memory
cd /projects/PROJECT
trap 'rm -f .passfile' EXIT        # fallback removal of passphrase
mkdir -p plain results

singularity exec --fakeroot --bind "$PWD" analysis.sif \
  bash -c '
    set -euo pipefail
    exec 3< .passfile              # open the passphrase file ...
    rm -f .passfile                # ... and remove it before use
    gocryptfs -passfile /dev/fd/3 cipher plain
    exec 3<&-
    trap "rm -rf plain/tmp; fusermount -u plain" EXIT
    mkdir -p plain/tmp             # temporary files encrypted too
    export TMPDIR="$PWD/plain/tmp" STATATMP="$PWD/plain/tmp"
    Rscript analysis.R plain/dataset.dta results
  '
