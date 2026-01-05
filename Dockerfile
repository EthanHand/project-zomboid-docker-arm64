# === STAGE 1: BUILDER (The "Heavy" Lifting) ===
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    pkg-config \
    ccache \
    clang \
    llvm \
    lld \
    binfmt-support \
    libsdl2-dev libepoxy-dev libssl-dev \
    python3 python3-setuptools nasm python3-clang \
    g++-x86-64-linux-gnu \
    libstdc++-10-dev-i386-cross \
    libstdc++-10-dev-amd64-cross \
    libstdc++-10-dev-arm64-cross \
    squashfs-tools squashfuse \
    libc-bin \
    expect \
    curl \
    sudo \
    fuse \
    qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    qtdeclarative5-dev qml-module-qtquick2 \
    wget

WORKDIR /home/fex
RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    git checkout a08a6ce5de51f5e625357ecaed46c463aa1e3c99 && \
    mkdir Build && cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -G Ninja .. && \
    ninja install

# === STAGE 2: RUNNER (The Clean Image for DockerHub) ===
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Only install the libraries needed to RUN the apps
RUN apt-get update && apt-get install -y \
    libsdl2-2.0-0 libepoxy0 libssl3 \
    squashfuse libc-bin \
    curl \
    sudo \
    wget \
    vim \
    nano \
    tmux \
    binfmt-support \
    libqt5gui5 \
    libqt5widgets5 && \
    rm -rf /var/lib/apt/lists/*

# Copy the finished FEX binaries from the builder
COPY --from=builder /usr/bin/FEX* /usr/bin/

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam

WORKDIR /home/steam

# Setup RootFS and SteamCMD
RUN mkdir -p /home/steam/.fex-emu/RootFS /home/steam/Steam /home/steam/Zomboid && \
    wget -O /tmp/Ubuntu_22_04.tar.gz "https://www.dropbox.com/scl/fi/16mhn3jrwvzapdw50gt20/Ubuntu_22_04.tar.gz?rlkey=4m256iahwtcijkpzcv8abn7nf" && \
    tar xzf /tmp/Ubuntu_22_04.tar.gz -C /home/steam/.fex-emu/RootFS/ && \
    rm /tmp/Ubuntu_22_04.tar.gz && \
    echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > /home/steam/.fex-emu/Config.json && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam && \
    sed -i '/ulimit -n/d' /home/steam/Steam/steamcmd.sh

# Prime SteamCMD (Initializes the environment and updates SteamCMD itself)
RUN FEXInterpreter /home/steam/Steam/steamcmd.sh +login anonymous +quit

# Install Project Zomboid (Using the primed environment)
RUN FEXInterpreter /home/steam/Steam/steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/Zomboid/ \
    +login anonymous \
    +app_update 380870 validate \
    +quit && \
    rm -rf /home/steam/Steam/logs /home/steam/Steam/appcache

EXPOSE 16261-16262/udp 27015/tcp

WORKDIR /home/steam/Zomboid

ENTRYPOINT ["\bin\bash"]