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

IMAGE=gocryptfs-example

cd "$(dirname "$0")"

# --user keeps data/example.dta owned by you rather than by root
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/work "$IMAGE" \
    Rscript /work/01-make-example-data.R
