#!/usr/bin/env bash
# Phase 1: run on the approved workstation holding the plaintext data
set -euo pipefail
IMAGE=analysis        # image built from the Dockerfile
DATASET=dataset.dta   # plaintext file in the current directory

mkdir -p cipher plain

# Initialise (prompts for the passphrase and displays the master key)
docker run --rm -it -v "$PWD":/work "$IMAGE" \
  gocryptfs -init /work/cipher

# Mount, copy the data in, list the decrypted view, unmount
docker run --rm -it --privileged -v "$PWD":/work "$IMAGE" bash -c "
  set -e
  gocryptfs /work/cipher /work/plain
  cp /work/${DATASET} /work/plain/
  ls -la /work/plain/
  fusermount -u /work/plain
"
chmod 700 cipher
