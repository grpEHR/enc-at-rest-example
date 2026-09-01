#!/usr/bin/bash
#
# Phase 3 of the report on Isambard: access the encrypted data inside a Slurm
# compute job using a Singularity container.
#
# Before submitting, create the passphrase file (see 04-make-passfile.sh):
#
#     ./04-make-passfile.sh
#     sbatch job.slurm
#
# Amend the SBATCH settings, the account, and the paths as appropriate.

#SBATCH --job-name=analysis
#SBATCH --time=04:00:00
#SBATCH --nodes=1
#SBATCH --mem=16GB

cd /projects/projectid

# Create mount point
mkdir -p /projects/projectid/plain
# It is assumed that /projects/projectid/cipher exists and is populated from the
# file transfer (see 'Secure transfer' in the README)

# Mount, analyse, and unmount in a single container session
# (FUSE mount only persists within the container process)
singularity exec --fakeroot --bind "$PWD":"$PWD" gocryptfs-example.sif \
    bash -c '
        gocryptfs \
            --extpass "cat $PWD/.passfile && rm -f $PWD/.passfile" \
            "$PWD/cipher" "$PWD/plain"
        Rscript "$PWD/analysis.R" "$PWD/plain/example.dta" "$PWD/results"
        fusermount -u "$PWD/plain"
    '

# Fallback: ensure passphrase file is deleted
[ -f "$PWD/.passfile" ] && rm -f "$PWD/.passfile"
