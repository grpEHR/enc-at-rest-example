#!/usr/bin/env bash
# Run on the login node immediately before submitting the job.
# umask 077: the file is never readable by anyone else, even briefly
set -euo pipefail
cd /projects/PROJECT
read -r -s -p 'gocryptfs passphrase: ' PASS; echo
( umask 077; printf '%s\n' "$PASS" > .passfile )
unset PASS
