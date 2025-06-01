# steamcmd-docker-arm64

## [Get it from docker hub](https://hub.docker.com/r/teriyakigod/steamcmd)

This repository provides a Docker image for running SteamCMD on ARM64 architecture. SteamCMD is a command-line utility that allows you to install and manage dedicated game servers via Steam.

## Prerequisites

- A machine or environment with ARM64 architecture support.
- Docker installed on your ARM64 system.
- 16261-16262 Udp ports open

## Building the Docker Image

To build the Docker image, follow these steps:

1. Clone this repository to your local machine:

   ```bash
   git clone https://github.com/EthanHand/project-zomboid-docker-arm64.git
   ```

2. Navigate to the repository's directory:

   ```bash
   cd project-zomboid-docker-arm64
   ```

3. Build the Docker image using the provided `Dockerfile`:

   ```bash
   sudo docker build -t pzomboid .
   ```

   This command will build the Docker image named "pzomboid"

## Running the SteamCMD Docker Container

Once you've built the Docker image, you can run the SteamCMD container using the following steps:

1. Run the SteamCMD container:

   ```bash
   sudo docker run -it --name zomboid-server -p 16261:16261/udp -p 16262:16262/udp -p 27015:27015/tcp pzomboid
   ```

   This command starts an interactive session inside the container.
   When you start the container the steamcmd runs and downloads Project Zomboid Dedicated Server automatically.
   The server is downloaded to /home/steam/Zomboid/

2. Navigate to the server directory

   ```bash
   cd /home/steam/Zomboid/
   ```
3. Start the server to generate server files

   ```bash
   FEXBash ./start-server.sh
   ```
4. Close the server and make changes you want in /home/steam/Zomboid/Server/

   ```bash
   vim servertest.ini
   ```

## To detatch from the container

   ```bash
   Ctrl + p, Ctrl + q
   ```

## To reattach

1. Find the container id

   ```bash
   docker ps
   ```

2. Reattach

   ```bash
   docker attach <container-id>
   ```

## If server hangs

  ```bash
  docker restart <container-id>
  ```

## Additional Information

1. If you need to make modifications to the container the root password is: `steamcmd`.

- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [Docker Documentation](https://docs.docker.com/)
