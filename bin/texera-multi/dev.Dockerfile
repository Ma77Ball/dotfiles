# Texera dev box: a full toolchain + an inner Docker daemon (docker-in-docker).
#
# Built ONCE (texera box build) and reused by every checkout. Each
# checkout runs one privileged container from this image with its source
# bind-mounted; `texera <cmd>` then execs INSIDE that container, so
# fresh / refresh / app / obs / debug / docker all build and run the checkout's
# REAL code, fully isolated (own localhost, own port space, own inner dockerd).
#
# Base is temurin-17 (glibc + JDK 17, the version Texera pins: JDK 24+ breaks
# Hadoop/Iceberg). We add Node 24, yarn, sbt, rust, protoc and docker-ce.
FROM eclipse-temurin:17-jdk-jammy

ENV DEBIAN_FRONTEND=noninteractive

# --- base OS packages + Docker (dind) ---------------------------------------
# docker-ce provides both the CLI and dockerd; the container runs its own
# daemon (see dev-entrypoint.sh). The packages mirror what texera
# expects on a dev host; protoc is installed separately below.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release git unzip zip tmux \
        lsof iproute2 procps sudo netcat-openbsd \
        postgresql-client python3 python3-pip python3-venv python3-dev build-essential \
        libpq-dev \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
         | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
         https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
         > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# --- Node 24 + yarn (via corepack) ------------------------------------------
# NodeSource for Node 24 (Angular 21). corepack activates the yarn version the
# frontend pins in package.json (packageManager) at install time.
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && corepack enable \
    && rm -rf /var/lib/apt/lists/*
# corepack otherwise prompts "Do you want to download <yarn>? [Y/n]" the first
# time it activates the frontend's pinned yarn, which hangs a non-interactive
# `yarn start`. Auto-accept downloads.
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

# Official protoc release: unlike Ubuntu's protobuf-compiler it bundles the
# google/protobuf well-known types, which bin/python-proto-gen.sh needs
# ("google/protobuf/descriptor.proto: File not found" otherwise). 3.19.4
# matches the repo pin (bin/protoc-version.txt). Also satisfies the Rust
# worker build (PROTOC).
ARG PROTOC_VERSION=3.19.4
RUN arch="$(uname -m)"; [ "$arch" = aarch64 ] && arch=aarch_64; \
    curl -fsSL -o /tmp/protoc.zip \
        "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${arch}.zip" \
    && unzip -oq /tmp/protoc.zip -d /usr/local bin/protoc 'include/*' \
    && chmod +x /usr/local/bin/protoc && rm /tmp/protoc.zip

# betterproto[compiler] + its protoc plugin, so Python-proto generation works
# in the box (Python UDF workers / pytest). Without it texera warns and
# skips proto-gen. Kept loose here; the repo pins the exact version at runtime.
RUN pip3 install --no-cache-dir 'betterproto[compiler]'

# --- sbt launcher ------------------------------------------------------------
# The launcher self-selects the sbt version the project declares in
# project/build.properties, so the pinned version here only bootstraps it.
ARG SBT_VERSION=1.10.7
RUN curl -fsSL "https://github.com/sbt/sbt/releases/download/v${SBT_VERSION}/sbt-${SBT_VERSION}.tgz" \
        | tar -xz -C /opt \
    && ln -s /opt/sbt/bin/sbt /usr/local/bin/sbt

# --- Rust (for the native amber-worker: rust:<op> operators) ----------------
ENV RUSTUP_HOME=/usr/local/rustup CARGO_HOME=/usr/local/cargo
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path --default-toolchain stable \
    && chmod -R a+rwX "$CARGO_HOME"

# --- env expected by texera inside the box ----------------------------
# require_jdk17 / require_node24 fall back to these when SDKMAN/nvm are absent
# (they are, in this image). PATH picks up sbt, cargo and the mounted dotfiles
# bin (texera itself lives at /opt/dotbin).
ENV JAVA_HOME=/opt/java/openjdk \
    TEXERA_JAVA_HOME=/opt/java/openjdk \
    TEXERA_NODE_HOME=/usr \
    PROTOC=/usr/local/bin/protoc \
    TEXERA_DEV_CONTAINER=1 \
    PATH=/opt/dotbin:/opt/sbt/bin:/usr/local/cargo/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY dev-entrypoint.sh /usr/local/bin/dev-entrypoint.sh
RUN chmod +x /usr/local/bin/dev-entrypoint.sh

# ng serve (4200), web API (8080) and the engine ports are reached through the
# proxy on the texera-proxy network; nothing is published to the host directly.
EXPOSE 4200 8080
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
