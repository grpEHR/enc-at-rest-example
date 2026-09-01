# Encryption at rest with gocryptfs — worked example

A small, self-contained, runnable example of the workflow described in
*Encryption at Rest for Research Data on Unencrypted High Performance Computing
Infrastructure: Implementation using gocryptfs* (Palmer, Denholm, Walker,
Madley-Dowd and Sterne, Electronic Health Records Group, Population Health
Sciences, Bristol Medical School, University of Bristol, 4 March 2026).

[gocryptfs](https://nuetzlich.net/gocryptfs/) is an open-source encrypted
overlay filesystem. It encrypts file contents and file names using AES-256-GCM,
with the master key derived from a passphrase via scrypt. Data is stored on
disk only as ciphertext; decryption happens block-by-block in memory through a
FUSE mount that exists only for the lifetime of the process that created it.

**The encrypted example dataset is committed to this repository**, so you can
clone it and decrypt and analyse the data straight away.

## The passphrase

```
grpehr
```

It is also in [`passphrase.txt`](passphrase.txt), which the scripts read so
that the whole example runs unattended.

> This is only appropriate because the dataset here is synthetic and generated
> by [`01-make-example-data.R`](01-make-example-data.R). In real use the
> passphrase is typed at an interactive prompt and never written to a file in
> the project directory, except for the short-lived mode-600 `.passfile` needed
> for batch jobs (see [Running it on Isambard](#running-it-on-isambard)).

## What is in the repository

| Path | What it is |
| --- | --- |
| `justfile` | Shortcuts for all of the steps below (`just --list`) |
| `Dockerfile` | Ubuntu 24.04 + `gocryptfs`, `fuse3` and the analysis software (R + haven) |
| `cipher/` | **The encrypted dataset.** Ciphertext plus `gocryptfs.conf` and `gocryptfs.diriv` |
| `passphrase.txt` | The passphrase, `grpehr` |
| `01-make-example-data.sh` | Runs `01-make-example-data.R` in the container to generate `data/example.dta` |
| `01-make-example-data.R` | Generates the synthetic plaintext dataset |
| `02-encrypt.sh` | Phase 1: initialises `cipher/` and encrypts the dataset into it |
| `03-mount-and-analyse.sh` | Phase 3, locally with Docker: mount, analyse, unmount |
| `04-make-passfile.sh` | Pre-submission step for a Slurm job: writes the mode-600 `.passfile` |
| `job.slurm` | Phase 3 on Isambard: Singularity + Slurm batch script |
| `analysis.R` | The analysis, run against the mounted plaintext view |

`data/` (plaintext), `plain/` (the mount point) and `results/` are all in
`.gitignore` — nothing but ciphertext is ever committed.

## Requirements

Docker: on macOS and Windows, Docker Desktop; on Linux, Docker Engine. The
container needs `--privileged` in order to create a FUSE mount.

Optionally [`just`](https://just.systems), for the shortcuts in the `justfile`.
Every recipe is a one-line wrapper around a numbered script, so nothing needs
`just` to run.

Nothing else. gocryptfs, FUSE, R and haven all live inside the container, so
none of them need to be installed on the host — including for the optional
data-generation step.

## Run the example

```sh
git clone <this repository>
cd enc-at-rest-example

# The encrypted data is owner-only on disk (git does not record directory modes)
chmod 700 cipher

# Build the container image
docker build -t gocryptfs-example .

# Mount the encrypted directory, run the analysis, unmount
./03-mount-and-analyse.sh
```

Or, with `just`, the last two steps are `just demo`.

Expected output:

```
Reading /work/plain/example.dta via the gocryptfs mount

Rows: 500  Columns: 6

Summary statistics
   n mean_age sd_age mean_sbp pct_treated pct_event
 500     63.3   10.8    137.3          47      24.8

Logistic regression: event ~ treated + age + sbp
            Estimate Std. Error z value Pr(>|z|)
(Intercept)  -4.4554     1.0838 -4.1108   0.0000
treated      -0.5870     0.2167 -2.7094   0.0067
age           0.0283     0.0099  2.8670   0.0041
sbp           0.0129     0.0059  2.2075   0.0273

Results written to /work/results
```

The three things worth noticing:

1. `cipher/` contains only ciphertext with encrypted file names, e.g.
   `ufWtU9aFK-iI34kmo7uwcw`. Try `file cipher/*`, or `just inspect`.
2. `plain/` is empty on disk before and after the run. The decrypted view
   existed only inside the container process. `just explore` drops you into a
   shell inside the mount, and it disappears when you exit.
3. `results/` contains aggregate, non-disclosive output only.

To see what happens without the passphrase, try mounting with the wrong one:

```sh
mkdir -p plain
docker run --rm -it --privileged -v "$PWD":/work gocryptfs-example \
    gocryptfs /work/cipher /work/plain     # type anything but 'grpehr'
```

(`just wrong-passphrase` does the same.)

## just recipes

Every step has a recipe; `just` on its own lists them.

| Recipe | What it does |
| --- | --- |
| `just demo` | Build the image and run the analysis — the whole example |
| `just build` | Build the container image |
| `just analyse` | Decrypt `cipher/` and run the analysis |
| `just inspect` | Show that `cipher/` holds only ciphertext |
| `just explore` | Shell inside the mounted plaintext view; exit destroys the mount |
| `just wrong-passphrase` | Try mounting with a passphrase you type yourself |
| `just data` | Generate the synthetic plaintext dataset |
| `just encrypt` | Generate the dataset and encrypt it into `cipher/` |
| `just reencrypt` | Discard `cipher/` and encrypt from scratch |
| `just sif` | Convert the image to Singularity format for Isambard |
| `just transfer <host>` | `scp -r cipher/` to the HPC facility |
| `just submit [projectdir]` | Write the passphrase file and `sbatch job.slurm` |
| `just clean` | Remove `results/`, `plain/` and `data/` |
| `just clean-all` | Also remove `cipher/`, the `.sif` and the image |

## Re-creating the encrypted directory from scratch

To go through Phase 1 yourself rather than using the committed `cipher/`:

```sh
rm -rf cipher

# Generate the synthetic plaintext dataset (runs R inside the container)
./01-make-example-data.sh

# Initialise cipher/ and encrypt data/example.dta into it
./02-encrypt.sh
```

`just reencrypt` does all three.

`02-encrypt.sh` runs the two commands from the report — first
`gocryptfs -init` to create the encrypted directory, then a mount into which
the plaintext dataset is copied, followed by `fusermount -u`. Afterwards
`cipher/` holds the encrypted dataset plus `gocryptfs.conf` and
`gocryptfs.diriv`, and `plain/` is empty again.

Note that the ciphertext file name will differ from the one committed here:
re-initialising generates a new master key, so nothing about the new `cipher/`
matches the old one even though the passphrase is the same. The regenerated
`data/example.dta` will also not be byte-identical to the one encrypted here,
because Stata files carry a creation timestamp in their header. The data itself
is identical — the script sets a fixed random seed — so the analysis gives the
same numbers.

For a real dataset you would run those commands interactively so gocryptfs
prompts for the passphrase, rather than reading it from `passphrase.txt`:

```sh
mkdir -p cipher plain

docker run --rm -it -v "$PWD":/work gocryptfs-example \
    gocryptfs -init /work/cipher

docker run --rm -it --privileged -v "$PWD":/work gocryptfs-example \
    bash -c '
        gocryptfs /work/cipher /work/plain
        cp /work/data/example.dta /work/plain/
        ls -la /work/plain/
        fusermount -u /work/plain
    '
```

## Secure transfer

Only `cipher/` is transferred to the HPC facility. It contains no plaintext, and
SSH encrypts it again in transit.

```sh
scp -r cipher/ PROJECT.FACILITY.isambard:
```

See the [Isambard file transfer
documentation](https://docs.isambard.ac.uk/user-documentation/guides/file_transfer/).

## Running it on Isambard

Isambard uses Singularity rather than Docker. Convert the image:

```sh
singularity build --fakeroot gocryptfs-example.sif \
    docker://<address.to.docker.container.image>
```

A Slurm batch job has no interactive terminal, so the passphrase is supplied
through a temporary mode-600 file which gocryptfs reads and deletes atomically
at mount time via `--extpass`:

```sh
./04-make-passfile.sh          # prompts for the passphrase, writes .passfile
sbatch job.slurm
```

[`job.slurm`](job.slurm) mounts, analyses and unmounts inside a **single**
`singularity exec` call. This matters: the FUSE mount exists only within the
container's process namespace, so if the container exits — at the end of the
job or because of an error — the mount is destroyed and later container
invocations cannot reach the decrypted data. The job script also contains a
fallback deletion of `.passfile` in case `--extpass` does not run.

## Caveats

- The passphrase in this repository is deliberately public. Never do this with
  a real dataset, and never commit a real `cipher/` directory to a repository
  that anyone else can read.
- The synthetic dataset is generated by `01-make-example-data.R`. It contains
  no real patient data.
- During an active job the data is decrypted in memory. Someone with root on
  the compute node could in principle inspect process memory; this is common to
  all encryption-at-rest solutions and is mitigated by the facility's own access
  controls.

## References

- gocryptfs: <https://github.com/rfjakob/gocryptfs>, <https://nuetzlich.net/gocryptfs/>
- Security audit: Hornby T, *Security Audit of gocryptfs v1.2*, Defuse Security,
  6 March 2017. <https://defuse.ca/audits/gocryptfs.htm>
- FUSE: <https://github.com/libfuse/libfuse>
- Bristol Centre for Supercomputing (BriCS): <https://docs.isambard.ac.uk/>
- NIST SP 800-38D: Dworkin M (2007), *Recommendation for Block Cipher Modes of
  Operation: Galois/Counter Mode (GCM) and GMAC*.
  <https://doi.org/10.6028/NIST.SP.800-38D>
