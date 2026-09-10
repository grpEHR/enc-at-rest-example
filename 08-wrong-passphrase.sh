#!/usr/bin/env bash
#
# Tries to mount cipher/ with a passphrase you type yourself. Anything but
# 'grpehr' fails: gocryptfs cannot derive the master key, so the mount never
# happens and no plaintext is produced.
#
# (If you do type the right one, gocryptfs backgrounds itself and the container
# then exits, which destroys the mount straight away - so plain/ ends up empty
# either way.)
#
# Usage:  ./08-wrong-passphrase.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

require_cipher

mkdir -p plain

if run_container --fuse --tty -- gocryptfs -nosyslog cipher plain; then
    echo
    echo "That was the right passphrase."
else
    echo
    echo "Mount refused, as expected: without the passphrase the master key"
    echo "cannot be derived and cipher/ stays unreadable."
fi

echo "plain/ on disk:"
ls -A plain/ || true
