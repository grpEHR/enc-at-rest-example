# Encryption at rest with gocryptfs — worked example

A small, self-contained, runnable example of the workflow described in
*Encryption at Rest for Research Data on Unencrypted High Performance Computing
Infrastructure: Implementation using gocryptfs* (Palmer, Denholm, Walker,
Madley-Dowd and Sterne, Electronic Health Records Group, Population Health
Sciences, Bristol Medical School, University of Bristol, 1 September 2026, [DOI](https://doi.org/10.6084/m9.figshare.33320925)).

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
| `Makefile` | The same shortcuts, for machines without `just` (`make help`) |
| `LICENSE` | MIT |
| `Dockerfile` | Ubuntu 24.04 + `gocryptfs`, `fuse3` and the analysis software (R + haven) |
| `gocryptfs-example.def` | The same image as an Apptainer/Singularity definition file, for HPC |
| `container.sh` | Detects Docker or Apptainer and defines how the scripts invoke the container |
| `cipher/` | **The encrypted dataset.** Ciphertext plus `gocryptfs.conf` and `gocryptfs.diriv` |
| `passphrase.txt` | The passphrase, `grpehr` |
| `00-build.sh` | Builds the image: a Docker image, or a `.sif` under Apptainer |
| `01-make-example-data.sh` | Runs `01-make-example-data.R` in the container to generate `data/example.dta` |
| `01-make-example-data.R` | Generates the synthetic plaintext dataset |
| `02-encrypt.sh` | Phase 1: initialises `cipher/` and encrypts the dataset into it |
| `03-mount-and-analyse.sh` | Phase 3: mount, analyse, unmount |
| `04-make-passfile.sh` | Pre-submission step for a Slurm job: writes the mode-600 `.passfile` |
| `05-interactive.sh` | Phase 3 on Isambard, interactively: no passphrase file needed |
| `06-inspect.sh` | Shows that `cipher/` holds only ciphertext |
| `07-explore.sh` | Shell inside the mounted plaintext view |
| `08-wrong-passphrase.sh` | Tries to mount with a passphrase you type yourself |
| `09-transfer-image.sh` | Copies the image to an HPC facility as a tarball and converts it there |
| `10-publish-image.sh` | Builds for amd64 + arm64 and pushes to a registry |
| `job.slurm` | Phase 3 on Isambard: Apptainer + Slurm batch script |
| `analysis.R` | The analysis, run against the mounted plaintext view |

`data/` (plaintext), `plain/` (the mount point) and `results/` are all in
`.gitignore` — nothing but ciphertext is ever committed.

## Requirements

A container runtime — either one:

- **Docker**, on a laptop or workstation: Docker Desktop on macOS and Windows,
  Docker Engine on Linux. The container needs `--privileged` in order to create
  a FUSE mount.
- **Apptainer** (formerly Singularity), on an HPC facility such as Isambard,
  where Docker is unavailable because it needs a root-owned daemon. Apptainer
  is daemonless and unprivileged; `--fakeroot` gives the container the
  capability it needs to mount `/dev/fuse`.

[`container.sh`](container.sh) detects which one is present, so the same
scripts work on both. Set `RUNTIME=docker|apptainer|singularity` to override it.

Optionally [`just`](https://just.systems), for the shortcuts in the `justfile`.
Every recipe is a one-line wrapper around a numbered script, so nothing needs
`just` to run — and where `just` is not installed, [`Makefile`](Makefile) has
the same targets.

Nothing else. gocryptfs, FUSE, R and haven all live inside the container, so
none of them need to be installed on the host — including for the optional
data-generation step.

## Run the example

```sh
git clone <this repository>
cd enc-at-rest-example

# The encrypted data is owner-only on disk (git does not record directory modes)
chmod 700 cipher

# Build the container image (Docker image, or .sif under Apptainer)
./00-build.sh

# Mount the encrypted directory, run the analysis, unmount
./03-mount-and-analyse.sh
```

Or, with `just`, the last two steps are `just demo`; with `make`, `make demo`.

Expected output:

```
Reading plain/example.dta via the gocryptfs mount

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

Results written to results
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
./08-wrong-passphrase.sh      # type anything but 'grpehr'
```

(`just wrong-passphrase` and `make wrong-passphrase` do the same.)

## Recipes

Every step has a recipe. Run `just` on its own to list them, or `make help`.
Both are wrappers around the numbered scripts, which can always be run directly.

| `just` | `make` | What it does |
| --- | --- | --- |
| `just demo` | `make demo` | Build the image and run the analysis — the whole example |
| `just build` | `make build` | Build the container image |
| `just analyse` | `make analyse` | Decrypt `cipher/` and run the analysis |
| `just inspect` | `make inspect` | Show that `cipher/` holds only ciphertext |
| `just explore` | `make explore` | Shell inside the mounted plaintext view; exit destroys the mount |
| `just wrong-passphrase` | `make wrong-passphrase` | Try mounting with a passphrase you type yourself |
| `just data` | `make data` | Generate the synthetic plaintext dataset |
| `just encrypt` | `make encrypt` | Generate the dataset and encrypt it into `cipher/` |
| `just reencrypt` | `make reencrypt` | Discard `cipher/` and encrypt from scratch |
| `just interactive` | `make interactive` | Interactive Slurm session with the data mounted; exit to unmount |
| `just sif` | `make sif` | Build the Apptainer image explicitly |
| `just transfer-image [host] [dir]` | `make transfer-image HOST=... PROJECTDIR=...` | Copy the image to the HPC facility and convert it there |
| `just publish [ref]` | `make publish REF=...` | Build for amd64 + arm64 and push to a registry |
| `just transfer <host>` | `make transfer HOST=...` | `scp -r cipher/` to the HPC facility |
| `just submit` | `make submit` | Write the passphrase file and `sbatch job.slurm` |
| `just clean` | `make clean` | Remove `results/`, `plain/` and `data/` |
| `just clean-all` | `make clean-all` | Also remove `cipher/`, the `.sif` and the image |

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

`02-encrypt.sh` prompts for the passphrase rather than reading
`passphrase.txt`, which is what you would do with a real dataset. Written out
in full, and with Docker, the two commands it runs are:

```sh
mkdir -p cipher plain

docker run --rm -it -v "$PWD":/work gocryptfs-example \
    gocryptfs -init cipher

docker run --rm -it --privileged -v "$PWD":/work gocryptfs-example \
    bash -c '
        gocryptfs cipher plain
        cp data/example.dta plain/
        ls -la plain/
        fusermount -u plain
    '
```

Under Apptainer the same two commands are `apptainer exec --bind "$PWD"
gocryptfs-example.sif ...` and `apptainer exec --fakeroot --bind "$PWD"
gocryptfs-example.sif ...`. `container.sh` is what hides that difference: both
runtimes are invoked so that the project directory is the working directory
inside the container, which is why the paths above are relative and identical
in either case.

## Secure transfer

Only `cipher/` is transferred to the HPC facility. It contains no plaintext, and
SSH encrypts it again in transit.

```sh
scp -r cipher/ PROJECT.FACILITY.isambard:
```

See the [Isambard file transfer
documentation](https://docs.isambard.ac.uk/user-documentation/guides/file_transfer/).

## Running it on Isambard

Isambard has no Docker — Docker needs a root-owned daemon, which is not
something a shared facility will run — and no `just`. It does have
[Apptainer](https://docs.isambard.ac.uk/user-documentation/guides/containers/apptainer/)
and `make`, which is all this example needs.

### Building the image

Isambard nodes are Arm 64 (`aarch64`), so **a `.sif` built on an x86_64 machine
will not run there**. Build it on Isambard from
[`gocryptfs-example.def`](gocryptfs-example.def), which installs the same
software as the `Dockerfile`:

```sh
git clone https://github.com/grpEHR/enc-at-rest-example.git
cd enc-at-rest-example
./00-build.sh            # or: make build
```

`00-build.sh` runs `apptainer build --fakeroot gocryptfs-example.sif
gocryptfs-example.def`, and points `APPTAINER_TMPDIR` and `APPTAINER_CACHEDIR`
at the project directory rather than `$HOME`, which is usually quota'd. The
BriCS documentation suggests doing builds on a compute node rather than the
login node:

```sh
srun --nodes=1 --pty --interactive bash
./00-build.sh
```

### If `--fakeroot` will not build the image

`apptainer build --fakeroot` runs `apt` inside the container, which needs a
working `/etc/subuid` mapping. Where that is unavailable the build fails part
way through `dpkg --configure`. Two routes avoid it entirely, because both only
repack layers that already exist and so need no fakeroot at all.

**Copy the image over.** From the workstation that has Docker:

```sh
export ISAMBARD_HOST=b35ck.3.isambard
export ISAMBARD_DIR=/projects/b35ck/enc-at-rest-example
just transfer-image          # or: make transfer-image HOST=... PROJECTDIR=...
```

That runs `docker save`, copies the tarball across, converts it with `apptainer
build docker-archive://`, and removes the tarball at both ends. It is about
110 MB over the wire. An Apple Silicon Mac already produces `linux/arm64`
images; on an x86_64 host, build with `docker build --platform linux/arm64`
first.

**Or publish it once and pull it.** From the workstation:

```sh
docker login
export DOCKERHUB_USER=myaccount
just publish                 # or: make publish REF=myaccount/gocryptfs-example
```

Then on Isambard, and on every later clone:

```sh
./00-build.sh myaccount/gocryptfs-example    # or: make build REF=...
```

`10-publish-image.sh` builds for `linux/amd64` and `linux/arm64` so the same
tag works on both a workstation and Isambard. On an Apple Silicon Mac the
amd64 half is emulated and takes several minutes.

### Running the analysis

Interactively, which is the simplest way to check everything works:

```sh
./05-interactive.sh          # or: just interactive / make interactive
```

That starts an interactive Slurm session, prompts for the passphrase at the
terminal — so no passphrase file is ever written — mounts `cipher/` at `plain/`
and drops you into a shell inside the container. Exiting unmounts the data.

As a batch job, where there is no interactive terminal, the passphrase is
supplied through a temporary mode-600 file that `job.slurm` opens on a file
descriptor and deletes before use, so it exists on disk only between submission
and mount:

```sh
./04-make-passfile.sh        # prompts, writes .passfile
sbatch job.slurm
```

Run both from the project directory — the one holding `cipher/`, `analysis.R`
and the `.sif`. Slurm starts the job in the directory `sbatch` was invoked
from, so there is nothing to configure in `job.slurm`; it checks that the three
files it needs are present and exits with a clear message if not.

[`job.slurm`](job.slurm) mounts, analyses and unmounts inside a **single**
`apptainer exec` call. This matters: the FUSE mount exists only within the
container's process namespace, so if the container exits — at the end of the
job or because of an error — the mount is destroyed and later container
invocations cannot reach the decrypted data. The job script also contains a
fallback deletion of `.passfile` in case the job fails before the mount.

### If you want `just` on Isambard anyway

It is a single static binary and needs no root:

```sh
mkdir -p ~/.local/bin
curl -fsSL https://github.com/casey/just/releases/download/1.58.0/just-1.58.0-aarch64-unknown-linux-musl.tar.gz \
    | tar xz -C ~/.local/bin just
export PATH="$HOME/.local/bin:$PATH"      # add to ~/.bashrc
```

The `Makefile` exists so that this is optional.

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

## License

MIT — see [`LICENSE`](LICENSE).

gocryptfs itself is separately licensed (MIT); see
<https://github.com/rfjakob/gocryptfs>.
