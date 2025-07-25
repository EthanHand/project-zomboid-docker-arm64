# Use the official Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary dependencies
RUN apt-get update && \
    apt-get install -y \
    git \
    cmake \
    ninja-build \
    pkg-config \
    ccache \
    clang \
    llvm \
    lld \
    binfmt-support \
    libsdl2-dev \
    libepoxy-dev \
    libssl-dev \
    python-setuptools \
    g++-x86-64-linux-gnu \
    nasm \
    python3-clang \
    libstdc++-10-dev-i386-cross \
    libstdc++-10-dev-amd64-cross \
    libstdc++-10-dev-arm64-cross \
    squashfs-tools \
    squashfuse \
    libc-bin \
    expect \
    curl \
    sudo \
    fuse \
    qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    qtdeclarative5-dev qml-module-qtquick2 \
    wget \
    vim \
    tmux

# Create a new user and set their home directory
RUN useradd -m -s /bin/bash fex

RUN usermod -aG sudo fex

RUN echo "fex ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/fex

USER fex

WORKDIR /home/fex

# Clone the FEX repository and build it
RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    git checkout a08a6ce5de51f5e625357ecaed46c463aa1e3c99 && \
    git submodule update --init --recursive && \
    mkdir Build && \
    cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -DENABLE_ASSERTIONS=False -G Ninja .. && \
    ninja

WORKDIR /home/fex/FEX/Build

# Run ninja install and enable binfmt_misc without systemd
RUN sudo ninja install && \
    sudo update-binfmts --enable

RUN sudo useradd -m -s /bin/bash steam

#RUN sudo apt install wget

USER root

RUN echo 'root:steamcmd' | chpasswd

USER steam

WORKDIR /home/steam/.fex-emu/RootFS/

# Set up rootfs

RUN wget -O Ubuntu_22_04.tar.gz https://www.dropbox.com/scl/fi/16mhn3jrwvzapdw50gt20/Ubuntu_22_04.tar.gz?rlkey=4m256iahwtcijkpzcv8abn7nf

RUN tar xzf Ubuntu_22_04.tar.gz

RUN rm ./Ubuntu_22_04.tar.gz

WORKDIR /home/steam/.fex-emu

RUN echo '{"Config":{"RootFS":"Ubuntu_22_04"}}' > ./Config.json

WORKDIR /home/steam/Steam

# Download and run SteamCMD
RUN curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

RUN sed -i '/ulimit -n/d' ./steamcmd.sh

RUN FEXInterpreter ./steamcmd.sh +@sSteamCmdForcePlatformType linux \
    +force_install_dir /home/steam/Zomboid/ \
    +login anonymous \
    +app_update 380870 validate \
    +quit > /dev/null

EXPOSE 16261-16262/udp \
   27015/tcp

WORKDIR /home/steam/Zomboid

ENTRYPOINT ["/bin/bash"]
