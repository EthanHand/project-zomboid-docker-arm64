# === STAGE 1: BUILDER ===
FROM ubuntu:22.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
# RUN apt-get update && apt-get install -y \
#     git \
#     cmake \
#     ninja-build \
#     pkg-config \
#     ccache \
#     clang \
#     llvm \
#     lld \
#     binfmt-support \
#     libsdl2-dev libepoxy-dev libssl-dev \
#     python3 python3-setuptools nasm python3-clang \
#     g++-x86-64-linux-gnu \
#     libstdc++-10-dev-i386-cross \
#     libstdc++-10-dev-amd64-cross \
#     libstdc++-10-dev-arm64-cross \
#     squashfs-tools squashfuse \
#     libc-bin \
#     expect \
#     curl \
#     sudo \
#     fuse \
#     qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
#     qtdeclarative5-dev qml-module-qtquick2 \
#     wget

# WORKDIR /home/fex
# RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
#     cd FEX && \
#     mkdir Build && cd Build && \
#     CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
#     -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -G Ninja .. && \
#     ninja install

# Install necessary dependencies for box64
RUN dpkg --add-architecture armhf && \
    apt-get update && apt-get install -y \
    libsdl2-2.0-0 libepoxy0 libssl3 curl sudo wget nano tmux \
    libc6:armhf libstdc++6:armhf \
    && rm -rf /var/lib/apt/lists/*

# Install build dependencies for Box86 and Box64
RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    build-essential \
    python3 \
    gcc-arm-linux-gnueabihf \
    libc6-dev-armhf-cros

# Build Box86 (SteamCMD 32 bit)
WORKDIR /build/box86
RUN git clone https://github.com/ptitSeb/box86.git . && \
    mkdir build && cd build && \
    cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    ninja && ninja install

# Build Box64 (Zomboid Server 64 bit)
WORKDIR /build/box64
RUN git clone https://github.com/ptitSeb/box64.git . && \
    mkdir build && cd build && \
    cmake .. -DARM64=1 -DCMAKE_BUILD_TYPE=Release -G Ninja && \
    ninja && ninja install

# === STAGE 2: RUNNER ===
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Only install the libraries needed to RUN the apps
# RUN apt-get update && apt-get install -y \
#     libsdl2-2.0-0 libepoxy0 libssl3 \
#     squashfuse libc-bin \
#     curl \
#     sudo \
#     wget \
#     vim \
#     nano \
#     tmux \
#     binfmt-support \
#     libqt5gui5 \
#     libqt5widgets5 && \
#     rm -rf /var/lib/apt/lists/*

# Copy the finished FEX binaries from the builder
# COPY --from=builder /usr/bin/FEX* /usr/bin/

# Add armhf architecture for 32-bit library support (SteamCMD needs this)
RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y \
    libsdl2-2.0-0 libepoxy0 libssl3 \
    curl \
    sudo \
    wget \
    nano \
    tmux \
    # 32-bit libs for Box86/SteamCMD
    libc6:armhf libstdc++6:armhf libncurses5:armhf \
    && rm -rf /var/lib/apt/lists/*

# Copy emulators from builder
COPY --from=builder /usr/local/bin/box86 /usr/local/bin/box86
COPY --from=builder /usr/local/bin/box64 /usr/local/bin/box64
COPY --from=builder /usr/local/lib/box86 /usr/local/lib/box86
COPY --from=builder /usr/local/lib/box64 /usr/local/lib/box64

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam

WORKDIR /home/steam

# Setup RootFS and SteamCMD
# RUN mkdir -p /home/steam/.fex-emu/RootFS /home/steam/Steam /home/steam/Zomboid && \
#     wget -O /tmp/Ubuntu_22_04.tar.gz "https://www.dropbox.com/scl/fi/16mhn3jrwvzapdw50gt20/Ubuntu_22_04.tar.gz?rlkey=4m256iahwtcijkpzcv8abn7nf" && \
#     tar xzf /tmp/Ubuntu_22_04.tar.gz -C /home/steam/.fex-emu/RootFS/ && \
#     rm /tmp/Ubuntu_22_04.tar.gz && \
#     echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > /home/steam/.fex-emu/Config.json && \
#     curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam && \
#     sed -i '/ulimit -n/d' /home/steam/Steam/steamcmd.sh

# Prime SteamCMD (Initializes the environment and updates SteamCMD itself)
# RUN FEXInterpreter /home/steam/Steam/steamcmd.sh +login anonymous +quit

# # Install Project Zomboid (Using the primed environment)
# RUN FEXInterpreter /home/steam/Steam/steamcmd.sh \
#     +@sSteamCmdForcePlatformType linux \
#     +force_install_dir /home/steam/Zomboid/ \
#     +login anonymous \
#     +app_update 380870 -beta 42.13.1 validate \
#     +quit && \
#     rm -rf /home/steam/Steam/logs /home/steam/Steam/appcache

# Install SteamCMD and Project Zomboid Build 42
RUN mkdir -p /home/steam/Steam /home/steam/Zomboid && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam

# Prime SteamCMD (Initializes the environment and updates SteamCMD itself)
RUN box86 /home/steam/Steam/steamcmd.sh +login anonymous +quit

# Install Project Zomboid (Box86 for 32 bit steamcmd)
RUN box86 /home/steam/Steam/steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/Zomboid/ \
    +login anonymous \
    +app_update 380870 -beta 42.13.1 validate \
    +quit

EXPOSE 16261-16262/udp 27015/tcp

WORKDIR /home/steam/Zomboid

ENTRYPOINT ["/bin/bash"]