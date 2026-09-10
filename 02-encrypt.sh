#!/usr/bin/env bash
#
# Phase 1: run on the approved workstation holding the plaintext data.
#
# Initialises cipher/ (prompting for a passphrase and displaying the master
# key), then mounts it, copies the plaintext dataset in, and unmounts. After
# this, cipher/ holds only ciphertext and plain/ is empty again.
#
# Usage:  ./02-encrypt.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

DATASET=data/example.dta   # plaintext file produced by 01-make-example-data.sh

if [ ! -e "$DATASET" ]; then
    echo "$DATASET not found. Run ./01-make-example-data.sh first." >&2
    exit 1
fi

mkdir -p cipher plain

# Initialise (prompts for the passphrase and displays the master key)
run_container --tty -- gocryptfs -init cipher

# Mount, copy the data in, list the decrypted view, unmount
run_container --fuse --tty -- bash -c "
    set -e
    gocryptfs cipher plain
    cp '$DATASET' plain/
    ls -la plain/
    fusermount -u plain
"

chmod 700 cipher
