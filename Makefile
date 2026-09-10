# Makefile — the same shortcuts as the justfile, for machines without `just`.
#
# `just` is nicer (run `just` on its own to list the recipes with their
# documentation), but it is not usually installed on an HPC facility, and every
# recipe here is a one-line wrapper around a numbered script. Use whichever is
# available; they do the same things.
#
#   make demo     build the image and run the analysis
#   make help     list the targets
#
# Neither runner is required: the numbered scripts can always be run directly.

PROJECTDIR ?= .
HOST       ?=
IMAGE      := gocryptfs-example

.PHONY: help build analyse analyze demo data encrypt reencrypt inspect \
        explore wrong-passphrase sif transfer submit interactive clean clean-all

## List the available targets
help:
	grep -E '^[a-z-]+:' Makefile | cut -d: -f1 | sort -u | sed 's/^/  make /'

## Build the container image (Docker image or .sif, whichever applies)
build:
	./00-build.sh

## Decrypt the committed cipher/ and run the analysis - the main example
analyse:
	./03-mount-and-analyse.sh

analyze: analyse

## Build the image and run the analysis, from a fresh clone
demo: build analyse

## Generate the synthetic plaintext dataset data/example.dta
data:
	./01-make-example-data.sh

## Initialise cipher/ and encrypt data/example.dta into it
encrypt: data
	./02-encrypt.sh

## Discard cipher/ and encrypt the dataset again from scratch
reencrypt:
	rm -rf cipher
	$(MAKE) encrypt

## Show that cipher/ holds only ciphertext with encrypted file names
inspect:
	./06-inspect.sh

## Shell inside the mounted plaintext view; exit destroys the mount
explore:
	./07-explore.sh

## Try to mount with a passphrase you type yourself (anything but 'grpehr' fails)
wrong-passphrase:
	./08-wrong-passphrase.sh

## Build the Apptainer image explicitly (same as `make build` on HPC)
sif:
	RUNTIME=apptainer ./00-build.sh

## Copy the encrypted directory to the HPC facility: make transfer HOST=...
transfer:
	test -n "$(HOST)" || { echo "Usage: make transfer HOST=PROJECT.FACILITY.isambard" >&2; exit 1; }
	scp -r cipher/ $(HOST):

## Create the mode-600 passphrase file, then submit the Slurm job
submit:
	./04-make-passfile.sh $(PROJECTDIR)
	sbatch job.slurm

## Interactive Slurm session with the data mounted; exit to unmount
interactive:
	./05-interactive.sh $(PROJECTDIR)

## Remove generated results, the mount point and the plaintext dataset
clean:
	rm -rf results plain data

## Remove everything generated, including cipher/ and the images
clean-all: clean
	rm -rf cipher $(IMAGE).sif .apptainer-tmp .apptainer-cache
	-command -v docker >/dev/null && docker image rm $(IMAGE) || true
