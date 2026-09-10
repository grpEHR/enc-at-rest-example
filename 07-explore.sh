#!/usr/bin/env bash
#
# Opens a shell inside the mounted plaintext view. The mount exists only for
# the lifetime of the container process, so exiting the shell destroys it and
# plain/ is empty on disk again.
#
# Usage:  ./07-explore.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

require_cipher

mkdir -p plain

run_container --fuse --tty -- bash -c '
    set -e
    gocryptfs -nosyslog -passfile passphrase.txt cipher plain
    trap "fusermount -u plain 2>/dev/null || true" EXIT
    echo
    echo "Decrypted view at $PWD/plain - exit to destroy the mount."
    echo
    cd plain && bash
'
