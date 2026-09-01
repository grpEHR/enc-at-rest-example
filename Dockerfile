# Container image used for both the local encryption step and the analysis.
#
# The report's minimal image is just the first two packages:
#
#     FROM ubuntu:24.04
#     RUN apt-get update && apt-get install -y gocryptfs fuse3 && \
#         rm -rf /var/lib/apt/lists/*
#
# As the report notes, an image that is also used for the analysis additionally
# contains the analysis software and its packages. Here that is R plus haven
# (for reading the Stata .dta example dataset).

FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        gocryptfs \
        fuse3 \
        r-base-core \
        r-cran-haven \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
