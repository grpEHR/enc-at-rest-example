# container.sh — sourced by the numbered scripts, not run directly.
#
# Picks the container runtime that is actually present and defines
# run_container(), so that every step of the example works unchanged on a
# laptop with Docker and on an HPC facility such as Isambard, where Docker is
# unavailable and Apptainer (formerly Singularity) is used instead.
#
# Docker needs a root-owned daemon and --privileged to create a FUSE mount, so
# it is never available on a shared facility. Apptainer is daemonless and
# unprivileged by design; --fakeroot gives the container CAP_SYS_ADMIN inside a
# user namespace, which is what gocryptfs needs to mount /dev/fuse.
#
# Both runtimes are invoked so that the project directory is the working
# directory inside the container. Every path passed to run_container can
# therefore be relative, and is the same under either runtime.
#
# Set RUNTIME=docker|apptainer|singularity to override the detection.

IMAGE=${IMAGE:-gocryptfs-example}   # Docker image tag
SIF=${SIF:-$IMAGE.sif}              # Apptainer image file

if [ -z "${RUNTIME:-}" ]; then
    if command -v docker >/dev/null 2>&1; then
        RUNTIME=docker
    elif command -v apptainer >/dev/null 2>&1; then
        RUNTIME=apptainer
    elif command -v singularity >/dev/null 2>&1; then
        RUNTIME=singularity
    else
        echo "No container runtime found: install Docker, or use a machine" >&2
        echo "with Apptainer/Singularity. See the README." >&2
        exit 1
    fi
elif ! command -v "$RUNTIME" >/dev/null 2>&1; then
    echo "RUNTIME=$RUNTIME was requested, but $RUNTIME is not on PATH." >&2
    exit 1
fi

# run_container [--fuse] [--tty] [--as-user] -- COMMAND [ARG...]
#
#   --fuse     the command creates a FUSE mount (Docker: --privileged,
#              Apptainer: --fakeroot)
#   --tty      the command prompts for input, e.g. the passphrase
#   --as-user  write files as the invoking user rather than root
#
# The last two are Docker-only: Apptainer already runs as you, on your tty.
run_container() {
    local fuse= tty= as_user=

    while [ $# -gt 0 ]; do
        case "$1" in
            --fuse)    fuse=1    ;;
            --tty)     tty=1     ;;
            --as-user) as_user=1 ;;
            --)        shift; break ;;
            *)         break ;;
        esac
        shift
    done

    if [ "$RUNTIME" = docker ]; then
        local args=(run --rm -v "$PWD":/work)
        [ -n "$fuse" ]    && args+=(--privileged)
        [ -n "$tty" ]     && args+=(-it)
        [ -n "$as_user" ] && args+=(--user "$(id -u):$(id -g)")
        docker "${args[@]}" "$IMAGE" "$@"
    else
        [ -e "$SIF" ] || {
            echo "$SIF not found. Build it first: ./00-build.sh" >&2
            exit 1
        }
        local args=(exec --bind "$PWD")
        [ -n "$fuse" ] && args+=(--fakeroot)
        "$RUNTIME" "${args[@]}" "$SIF" "$@"
    fi
}

require_cipher() {
    [ -e cipher/gocryptfs.conf ] || {
        echo "cipher/ is not initialised. Run ./02-encrypt.sh first." >&2
        exit 1
    }
}
