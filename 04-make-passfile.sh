#!/usr/bin/env bash
#
# Pre-submission step for the HPC job: create the temporary passphrase file.
#
# Slurm batch jobs have no interactive terminal, so the passphrase cannot be
# typed at mount time. It is instead written to a mode-600 file which gocryptfs
# reads and deletes atomically at mount time via --extpass (see job.slurm).
#
# Usage:  ./04-make-passfile.sh
#         sbatch job.slurm
#
# For this example the passphrase is 'grpehr' (see passphrase.txt).

set -euo pipefail

PROJECTDIR=${1:-/projects/projectid}

# Create passphrase file (interactive prompt, not echoed)
read -s -p 'Enter gocryptfs passphrase: ' PASS
echo
echo "$PASS" > "$PROJECTDIR/.passfile"
chmod 600 "$PROJECTDIR/.passfile"
unset PASS

echo "Wrote $PROJECTDIR/.passfile (mode 600). It is deleted at mount time."
