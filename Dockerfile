# Software only: this image must never contain data
FROM ubuntu:24.04
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gocryptfs fuse3 r-base-core r-cran-haven && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /work
