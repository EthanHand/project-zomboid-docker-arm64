# FEX
# === STAGE 1: BUILDER ===
FROM ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install updated dependencies for 25.04
RUN apt-get update && apt-get install -y \
    git cmake ninja-build pkg-config ccache clang llvm lld \
    binfmt-support libsdl2-dev libepoxy-dev libssl-dev \
    python3 python3-setuptools nasm python3-clang \
    # Cross-compilers for the Guest Thunks
    gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
    gcc-i686-linux-gnu g++-i686-linux-gnu \
    # Specific headers for Ubuntu 25.04
    libstdc++-14-dev-i386-cross \
    libstdc++-14-dev-amd64-cross \
    libstdc++-14-dev-arm64-cross \
    # Utilities
    squashfs-tools squashfuse libc-bin expect curl sudo fuse3 \
    qt6-base-dev qt6-declarative-dev wget debootstrap && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /home/fex
RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    # git checkout a08a6ce5de51f5e625357ecaed46c463aa1e3c99 && \
    mkdir Build && cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_LINKER=lld \
    -DENABLE_LTO=True \
    -DBUILD_THUNKS=True \
    -DBUILD_TESTS=False -G Ninja .. && \
    ninja install

WORKDIR /rootfs_build
RUN debootstrap --arch=amd64 plucky ./ubuntu_25_04 http://archive.ubuntu.com/ubuntu/ && \
    chroot ./ubuntu_25_04 apt-get update && \
    chroot ./ubuntu_25_04 apt-get install -y libsdl3-0 libssl3t64 libepoxy0 && \
    tar -czf /ubuntu_25_04.tar.gz -C ./ubuntu_25_04 .

# === STAGE 2: RUNNER ===
FROM ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

# Note: libssl3 has been replaced by libssl3t64 in newer Ubuntu versions
RUN apt-get update && apt-get install -y \
    libsdl3-0 libsdl2-2.0-0 libepoxy0 libssl3t64 \
    squashfuse libc-bin \
    curl sudo wget vim nano tmux \
    binfmt-support libqt6gui6 libqt6widgets6 && \
    rm -rf /var/lib/apt/lists/*

# Copy the finished FEX binaries from the builder
COPY --from=builder /usr/bin/FEX* /usr/bin/
COPY --from=builder /usr/lib/fex-emu /usr/lib/fex-emu
COPY --from=builder /usr/share/fex-emu /usr/share/fex-emu
COPY --from=builder /ubuntu_25_04.tar.gz /tmp/

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam
WORKDIR /home/steam

# Setup RootFS
RUN mkdir -p /home/steam/.fex-emu/RootFS/Ubuntu_25_04 /home/steam/Steam /home/steam/Zomboid && \
    tar xzf /tmp/ubuntu_25_04.tar.gz -C /home/steam/.fex-emu/RootFS/Ubuntu_25_04/ && \
    echo '{"Config":{"RootFS":"Ubuntu_25_04"}}' > /home/steam/.fex-emu/Config.json

# Update the Config.json creation
RUN echo '{ \
  "Config": { \
    "RootFS": "Ubuntu_25_04", \
    "ThunkHostLibs": "/usr/lib/fex-emu/HostThunks", \
    "ThunkGuestLibs": "/usr/share/fex-emu/GuestThunks" \
  }, \
  "App-Config": { \
    "WaitGui": 0 \
  } \
}' > /home/steam/.fex-emu/Config.json

# Prime SteamCMD
RUN FEXInterpreter /home/steam/Steam/steamcmd.sh +login anonymous +quit

# Install Project Zomboid
RUN FEXInterpreter /home/steam/Steam/steamcmd.sh \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/Zomboid/ \
    +login anonymous \
    +app_update 380870 validate \
    +app_update 380870 -beta 42.13.1 validate \
    +quit && \
    rm -rf /home/steam/Steam/logs /home/steam/Steam/appcache

EXPOSE 16261-16262/udp 27015/tcp