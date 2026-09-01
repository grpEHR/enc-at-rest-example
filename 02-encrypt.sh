#!/usr/bin/env bash
#
# Phase 1 of the report: local encryption.
#
# Initialises the encrypted directory cipher/ and copies the plaintext dataset
# into it through a temporary gocryptfs FUSE mount. Only ciphertext is ever
# written to cipher/; plain/ is a mount point and is empty on disk once the
# mount is released.
#
# This is the step the data provider (or an approved researcher holding the
# data on an encrypted drive) performs on their local workstation.
#
# Usage:  ./02-encrypt.sh
#
# Prerequisites:
#   docker build -t gocryptfs-example .
#   ./01-make-example-data.sh           # creates data/example.dta
#
# NOTE ON THE PASSPHRASE
# ----------------------
# For a real dataset you would run the two docker commands below interactively
# with -it and no -passfile, so gocryptfs prompts for the passphrase and it is
# never written to disk:
#
#   docker run --rm -it -v "$PWD":/work gocryptfs-example \
#       gocryptfs -init /work/cipher
#
# This example instead reads the passphrase from passphrase.txt so that the
# demonstration is fully scripted and anyone can reproduce it.

set -euo pipefail

IMAGE=gocryptfs-example
DATASET=example.dta

cd "$(dirname "$0")"

if [ ! -f "data/${DATASET}" ]; then
    echo "data/${DATASET} not found. Run: ./01-make-example-data.sh" >&2
    exit 1
fi

# Create directories
mkdir -p cipher plain

if [ -e cipher/gocryptfs.conf ]; then
    echo "cipher/ is already initialised. Delete cipher/ first to start again." >&2
    exit 1
fi

# Initialise encrypted directory (AES-256-GCM, scrypt key derivation)
docker run --rm -v "$PWD":/work "$IMAGE" \
    gocryptfs -init -passfile /work/passphrase.txt /work/cipher

# Mount, copy data in, unmount
docker run --rm --privileged -v "$PWD":/work "$IMAGE" \
    bash -c "
        set -e
        gocryptfs -passfile /work/passphrase.txt /work/cipher /work/plain
        cp /work/data/${DATASET} /work/plain/
        ls -la /work/plain/
        fusermount -u /work/plain
    "

# Encrypted data is owner-only on disk
chmod 700 cipher

echo
echo "cipher/ now contains the encrypted dataset:"
ls -la cipher/
echo
echo "plain/ is empty again (it was only a temporary mount point):"
ls -A plain/ || true
