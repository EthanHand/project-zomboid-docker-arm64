# FEX
# === STAGE 1: BUILDER ===
FROM arm64v8/ubuntu:25.04 AS builder
ENV DEBIAN_FRONTEND=noninteractive

# Install builder dependencies
RUN apt-get update && apt-get install -y \
    git cmake ninja-build pkg-config ccache clang llvm lld \
    libsdl3-dev libsdl2-dev libepoxy-dev libssl-dev \
    python3 python3-setuptools nasm python3-clang libclang-dev \
    gcc-x86-64-linux-gnu g++-x86-64-linux-gnu \
    gcc-i686-linux-gnu g++-i686-linux-gnu \
    libstdc++-14-dev-i386-cross libstdc++-14-dev-amd64-cross \
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
    #-DBUILD_THUNKS=True \
    -DBUILD_TESTS=False -G Ninja .. && \
    ninja install

# === STAGE 2: RUNNER ===
FROM arm64v8/ubuntu:25.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libsdl3-0 libsdl2-2.0-0 libepoxy0 libssl3t64 \
    squashfuse libc-bin curl sudo wget vim nano tmux \
    binfmt-support libqt6gui6 libqt6widgets6 && \
    rm -rf /var/lib/apt/lists/*

# Copy the finished FEX binaries and trunks from the builder and ubuntu25.04 from rootfs
COPY --from=builder /usr/bin/FEX* /usr/bin/

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam
WORKDIR /home/steam

# Setup RootFS
RUN mkdir -p /home/steam/.fex-emu/RootFS/Ubuntu_25_04 /home/steam/Steam /home/steam/Zomboid && \
    wget -O /tmp/Ubuntu_25_04.tar.gz "https://www.dropbox.com/scl/fi/na3t1pwu1f8hwemtescjd/Ubuntu_25_04.tar.gz?rlkey=vhnm1jeuh09z6406lptn5izrx&st=eo4w8s9q&dl=1" && \
    tar xpzf /tmp/Ubuntu_25_04.tar.gz -C /home/steam/.fex-emu/RootFS/Ubuntu_25_04/ && \
    rm /tmp/Ubuntu_25_04.tar.gz && \
    sudo cp /etc/resolv.conf /home/steam/.fex-emu/RootFS/Ubuntu_25_04/etc/resolv.conf && \
    echo '{"Config":{"RootFS":"Ubuntu_25_04"}}' > /home/steam/.fex-emu/Config.json && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam && \
    sed -i '/ulimit -n/d' /home/steam/Steam/steamcmd.sh

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

WORKDIR /home/steam/Zomboid

ENTRYPOINT [ "/bin/bash" ]