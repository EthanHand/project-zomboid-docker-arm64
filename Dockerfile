# Box64
# === STAGE 1: BUILDER ===
FROM ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies for box64 and box86
RUN dpkg --add-architecture armhf && \
    apt-get update && apt-get install -y \
    git \
    cmake \
    ninja-build \
    build-essential \
    python3 \
    # These provide the cross-compilation headers for armhf
    gcc-arm-linux-gnueabihf \
    libc6-dev-armhf-cross \
    # Standard 64-bit headers
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Build Box86 (SteamCMD 32 bit)
WORKDIR /home/box86
RUN git clone --depth 1 https://github.com/ptitSeb/box86.git . && \
    mkdir build && cd build && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
      -DARM_DYNAREC=ON \
      -DARM64=1 \
      -DCMAKE_BUILD_TYPE=Release \
      -G Ninja && \
    ninja && ninja install

# Build Box64 (Zomboid Server 64 bit)
WORKDIR /home/box64
RUN git clone --depth 1 https://github.com/ptitSeb/box64.git . && \
    mkdir build && cd build && \
    cmake .. \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DARM64=1 \
      -DARM64_DYNAREC=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -G Ninja && \
    ninja && ninja install

# === STAGE 2: RUNNER ===
FROM ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

# 1. Enable Architectures
RUN dpkg --add-architecture armhf && \
    dpkg --add-architecture amd64

# 2. Configure Ubuntu 25.04 (Plucky) Multi-Arch Sources
# Restrict native sources to ARM
RUN sed -i 's/Types: deb/Architectures: arm64 armhf\nTypes: deb/g' /etc/apt/sources.list.d/ubuntu.sources

# Add AMD64 Sources for SDL3 and SQLite
RUN cat <<EOF > /etc/apt/sources.list.d/amd64.sources
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: plucky plucky-updates plucky-security
Components: main universe restricted multiverse
Architectures: amd64
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

# 3. Install Dependencies
RUN apt-get update && apt-get install -y \
    curl sudo wget nano tmux ca-certificates \
    libc6:armhf libstdc++6:armhf \
    libc6:amd64 libstdc++6:amd64 libgcc-s1:amd64 \
    libsdl3-0:amd64 libsqlite3-0:amd64 \
    libnuma1:amd64 \
    && rm -rf /var/lib/apt/lists/*

# Copy emulators from builder
COPY --from=builder /usr/bin/box86 /usr/bin/box86
COPY --from=builder /usr/bin/box64 /usr/bin/box64

ENV DEBUGGER "/usr/bin/box86"
ENV LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/usr/lib/arm-linux-gnueabihf:${LD_LIBRARY_PATH}"

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam

WORKDIR /home/steam

# Install SteamCMD and Project Zomboid Build 42
RUN mkdir -p /home/steam/Steam /home/steam/Zomboid && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam

# Prime and Run SteamCMD in a single layer
RUN /home/steam/Steam/steamcmd.sh +login anonymous +quit || true && \
    /home/steam/Steam/steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/Zomboid/ \
    +login anonymous \
    +app_update 380870 -beta 42.13.1 validate \
    +quit

USER root
RUN mkdir -p /home/steam/Zomboid/linux64 && \
    ln -sf /usr/lib/x86_64-linux-gnu/libstdc++.so.6 /home/steam/Zomboid/linux64/libstdc++.so.6 && \
    ln -sf /usr/lib/x86_64-linux-gnu/libgcc_s.so.1 /home/steam/Zomboid/linux64/libgcc_s.so.1 && \
    ln -sf /usr/lib/x86_64-linux-gnu/libSDL3.so.0 /home/steam/Zomboid/linux64/libSDL3.so.0 && \
    mkdir -p /home/steam/.steam/sdk64 && \
    ln -sf /home/steam/Zomboid/linux64/steamclient.so /home/steam/.steam/sdk64/steamclient.so

# Box64 Optimizations for Project Zomboid
ENV BOX64_JVM=1
ENV BOX64_DYNAREC_BIGBLOCK=0
ENV BOX64_DYNAREC_STRONGMEM=1
ENV LD_LIBRARY_PATH="/home/steam/Zomboid/linux64:/home/steam/Zomboid/natives:/home/steam/Zomboid/jre64/lib:."

USER steam
WORKDIR /home/steam

EXPOSE 16261-16262/udp 27015/tcp

WORKDIR /home/steam/Zomboid

ENTRYPOINT ["/bin/bash"]

# FEX
# # === STAGE 1: BUILDER (The "Heavy" Lifting) ===
# FROM ubuntu:22.04 AS builder
# ENV DEBIAN_FRONTEND=noninteractive

# # Install necessary dependencies
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
#     git checkout a08a6ce5de51f5e625357ecaed46c463aa1e3c99 && \
#     mkdir Build && cd Build && \
#     CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release \
#     -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -G Ninja .. && \
#     ninja install

# # === STAGE 2: RUNNER (The Clean Image for DockerHub) ===
# FROM ubuntu:22.04
# ENV DEBIAN_FRONTEND=noninteractive

# # Only install the libraries needed to RUN the apps
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

# # Copy the finished FEX binaries from the builder
# COPY --from=builder /usr/bin/FEX* /usr/bin/

# # Set up the steam user
# RUN useradd -m -s /bin/bash steam && \
#     echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

# USER steam

# WORKDIR /home/steam

# # Setup RootFS and SteamCMD
# RUN mkdir -p /home/steam/.fex-emu/RootFS /home/steam/Steam /home/steam/Zomboid && \
#     wget -O /tmp/Ubuntu_22_04.tar.gz "https://www.dropbox.com/scl/fi/16mhn3jrwvzapdw50gt20/Ubuntu_22_04.tar.gz?rlkey=4m256iahwtcijkpzcv8abn7nf" && \
#     tar xzf /tmp/Ubuntu_22_04.tar.gz -C /home/steam/.fex-emu/RootFS/ && \
#     rm /tmp/Ubuntu_22_04.tar.gz && \
#     echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > /home/steam/.fex-emu/Config.json && \
#     curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam && \
#     sed -i '/ulimit -n/d' /home/steam/Steam/steamcmd.sh

# # Prime SteamCMD (Initializes the environment and updates SteamCMD itself)
# RUN FEXInterpreter /home/steam/Steam/steamcmd.sh +login anonymous +quit

# # Install Project Zomboid (Using the primed environment)
# RUN FEXInterpreter /home/steam/Steam/steamcmd.sh \
#     +@sSteamCmdForcePlatformType linux \
#     +force_install_dir /home/steam/Zomboid/ \
#     +login anonymous \
#     +app_update 380870 validate \
#     +app_update 380870 -beta 42.13.1 validate \
#     +quit && \
#     rm -rf /home/steam/Steam/logs /home/steam/Steam/appcache

# EXPOSE 16261-16262/udp 27015/tcp