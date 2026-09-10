#!/usr/bin/env bash
#
# Shows that cipher/ holds only ciphertext, with encrypted file names. Runs
# entirely on the host: no container and no passphrase are involved, because
# nothing here decrypts anything.
#
# Usage:  ./06-inspect.sh

set -euo pipefail

cd "$(dirname "$0")"

# No container runtime is needed here: nothing in this script decrypts anything
[ -e cipher/gocryptfs.conf ] || {
    echo "cipher/ is not initialised. Run ./02-encrypt.sh first." >&2
    exit 1
}

echo "cipher/ on disk - file names and contents are both encrypted:"
ls -la cipher/
echo
file cipher/*
echo
echo "First bytes of the encrypted dataset:"
for f in cipher/*; do
    case "${f##*/}" in gocryptfs.*) continue ;; esac
    head -c 64 "$f" | od -c | head -4
done
