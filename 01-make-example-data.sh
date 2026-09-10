#!/usr/bin/env bash
#
# Generates the synthetic plaintext dataset data/example.dta by running
# 01-make-example-data.R inside the container, so that no R installation is
# needed on the host.
#
# You only need this if you want to re-create cipher/ from scratch with
# 02-encrypt.sh. To run the example against the encrypted data that is already
# committed to this repository, go straight to 03-mount-and-analyse.sh.
#
# Usage:  ./01-make-example-data.sh

set -euo pipefail

cd "$(dirname "$0")"
. ./container.sh

# --as-user keeps data/example.dta owned by you rather than by root
run_container --as-user -- Rscript 01-make-example-data.R
