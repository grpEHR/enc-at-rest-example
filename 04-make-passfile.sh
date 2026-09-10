#!/usr/bin/env bash
#
# Pre-submission step for a Slurm batch job: writes the mode-600 .passfile that
# job.slurm reads and immediately deletes. Run on the login node immediately
# before submitting the job.
#
# umask 077: the file is never readable by anyone else, even briefly.
#
# Usage:  ./04-make-passfile.sh [projectdir]

set -euo pipefail

PROJECTDIR=${1:-/projects/projectid}

cd "$PROJECTDIR"
read -r -s -p 'gocryptfs passphrase: ' PASS; echo
( umask 077; printf '%s\n' "$PASS" > .passfile )
unset PASS

echo "Wrote $PROJECTDIR/.passfile (mode 600). Submit the job now: sbatch job.slurm"
