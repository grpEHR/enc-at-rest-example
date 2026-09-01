# Encryption at rest with gocryptfs — worked example
#
# Run `just` to list the recipes. Everything runs inside the container, so
# Docker is the only requirement.

image   := "gocryptfs-example"
dataset := "example.dta"

# --privileged is needed for the container to create a FUSE mount
run_fuse := "docker run --rm --privileged -v \"$PWD\":/work"

# List the available recipes
default:
    @just --list --unsorted

# Build the container image (gocryptfs + fuse3 + R + haven)
build:
    docker build -t {{image}} .

# Decrypt the committed cipher/ and run the analysis — the main example
analyse: _require-cipher
    ./03-mount-and-analyse.sh
alias analyze := analyse

# Build the image and run the analysis, from a fresh clone
demo: build analyse

# --- Re-creating the encrypted directory (optional) --------------------------

# Generate the synthetic plaintext dataset data/example.dta
data:
    ./01-make-example-data.sh

# Initialise cipher/ and encrypt data/example.dta into it
encrypt: data
    ./02-encrypt.sh

# Discard cipher/ and encrypt the dataset again from scratch
reencrypt:
    rm -rf cipher
    @just encrypt

# --- Looking at what is actually on disk -------------------------------------

# Show that cipher/ holds only ciphertext with encrypted file names
inspect: _require-cipher
    @echo "cipher/ on disk — file names and contents are both encrypted:"
    @ls -la cipher/
    @echo
    @file cipher/*
    @echo
    @echo "First bytes of the encrypted dataset:"
    @for f in cipher/*; do \
        case "${f##*/}" in gocryptfs.*) continue ;; esac; \
        head -c 64 "$f" | od -c | head -4; \
    done

# Open a shell inside the mounted plaintext view (exit to destroy the mount)
explore: _require-cipher
    mkdir -p plain
    {{run_fuse}} -it {{image}} bash -c '\
        gocryptfs -passfile /work/passphrase.txt /work/cipher /work/plain; \
        echo; echo "Decrypted view at /work/plain — exit to destroy the mount."; echo; \
        cd /work/plain && bash; \
        fusermount -u /work/plain'

# Try to mount with a passphrase you type yourself (anything but 'grpehr' fails)
wrong-passphrase: _require-cipher
    mkdir -p plain
    -{{run_fuse}} -it {{image}} gocryptfs /work/cipher /work/plain

# --- HPC (Isambard) ----------------------------------------------------------

# Convert the Docker image to a Singularity image for Isambard
sif:
    singularity build --fakeroot {{image}}.sif docker://{{image}}

# Copy the encrypted directory to the HPC facility, e.g. `just transfer PROJECT.FACILITY.isambard`
transfer host: _require-cipher
    scp -r cipher/ {{host}}:

# Create the mode-600 passphrase file, then submit the Slurm job
submit projectdir="/projects/projectid":
    ./04-make-passfile.sh {{projectdir}}
    sbatch job.slurm

# --- Housekeeping ------------------------------------------------------------

# Remove generated results, the mount point and the plaintext dataset
clean:
    rm -rf results plain data

# Remove everything generated, including cipher/ and the container image
clean-all: clean
    rm -rf cipher {{image}}.sif
    -docker image rm {{image}}

_require-cipher:
    @test -e cipher/gocryptfs.conf || { \
        echo "cipher/ is not initialised. Run 'just encrypt' first." >&2; exit 1; }
