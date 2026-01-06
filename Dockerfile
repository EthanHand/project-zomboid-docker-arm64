# Box64
# === STAGE 1: BUILDER ===
FROM ubuntu:22.04 AS builder
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
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Add armhf architecture for 32-bit library support (SteamCMD needs this)
RUN dpkg --add-architecture armhf && apt-get update && apt-get install -y \
    curl sudo wget nano tmux ca-certificates \
    openjdk-21-jdk-headless \
    # 32-bit libs for Box86/SteamCMD
    libc6:armhf libstdc++6:armhf libncurses5:armhf \
    # 64-bit libs for Zomboid
    libsdl2-2.0-0 libepoxy0 libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy emulators from builder
COPY --from=builder /usr/bin/box86 /usr/bin/box86
COPY --from=builder /usr/bin/box64 /usr/bin/box64

# Set up the steam user
RUN useradd -m -s /bin/bash steam && \
    echo "steam ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/steam

USER steam

WORKDIR /home/steam

# Install SteamCMD and Project Zomboid Build 42
RUN mkdir -p /home/steam/Steam /home/steam/Zomboid && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - -C /home/steam/Steam

# System Link to box86
USER root
RUN ln -sf /usr/bin/box86 /home/steam/Steam/linux32/steamcmd && \
    ln -sf /usr/bin/box86 /usr/bin/steamcmd
USER steam

# Prime SteamCMD (Initializes the environment and updates SteamCMD itself)
RUN /home/steam/Steam/linux32/steamcmd +login anonymous +quit

# Install Project Zomboid (Box86 for 32 bit steamcmd)
RUN /home/steam/Steam/linux32/steamcmd \
    +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/Zomboid/ \
    +login anonymous \
    +app_update 380870 -beta 42.13.1 validate \
    +quit

EXPOSE 16261-16262/udp 27015/tcp

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-arm64
ENV PATH=$JAVA_HOME/bin:$PATH

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