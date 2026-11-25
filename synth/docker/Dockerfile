# Dockerfile for AFTxAI EDA Environment
# Extends the standard OpenROAD-flow-scripts image with Verilator for RTL verification
FROM openroad/orfs:latest

USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends verilator build-essential && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER openroad
WORKDIR /work
