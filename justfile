# Encryption at rest with gocryptfs — worked example
#
# Run `just` to list the recipes. Every recipe is a one-line wrapper around a
# numbered script, and each script picks the container runtime that is present:
# Docker on a laptop, Apptainer/Singularity on an HPC facility such as
# Isambard. Nothing here needs `just` itself — see the Makefile, or run the
# scripts directly.

image := "gocryptfs-example"

# List the available recipes
default:
    @just --list --unsorted

# Build the container image — Docker image, or .sif under Apptainer
build:
    ./00-build.sh

# Decrypt the committed cipher/ and run the analysis — the main example
analyse:
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
inspect:
    ./06-inspect.sh

# Open a shell inside the mounted plaintext view (exit to destroy the mount)
explore:
    ./07-explore.sh

# Try to mount with a passphrase you type yourself (anything but 'grpehr' fails)
wrong-passphrase:
    ./08-wrong-passphrase.sh

# --- HPC (Isambard) ----------------------------------------------------------

# Build the Apptainer image explicitly — same as `just build` on Isambard
sif:
    RUNTIME=apptainer ./00-build.sh

# Copy the encrypted directory to the HPC facility, e.g. `just transfer PROJECT.FACILITY.isambard`
transfer host: _require-cipher
    scp -r cipher/ {{ host }}:

# Create the mode-600 passphrase file, then submit the Slurm job
submit projectdir="/projects/projectid":
    ./04-make-passfile.sh {{ projectdir }}
    sbatch job.slurm

# Interactive session on Isambard: type the passphrase, get a shell with the data mounted
interactive projectdir="/projects/projectid":
    ./05-interactive.sh {{ projectdir }}

# --- Housekeeping ------------------------------------------------------------

# Remove generated results, the mount point and the plaintext dataset
clean:
    rm -rf results plain data

# Remove everything generated, including cipher/ and the images
clean-all: clean
    rm -rf cipher {{ image }}.sif .apptainer-tmp .apptainer-cache
    -docker image rm {{ image }}

_require-cipher:
    @test -e cipher/gocryptfs.conf || { \
        echo "cipher/ is not initialised. Run 'just encrypt' first." >&2; exit 1; }
