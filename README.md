# project-zomboid-docker-arm64

## [Get it from docker hub](https://hub.docker.com/r/etheth888/project-zomboid-arm64)

This repository provides a Docker image for running a Project Zomboid Dedicated Server using SteamCMD on ARM64 architecture. SteamCMD is a command-line utility that allows you to install and manage dedicated game servers via Steam.

## Prerequisites

- A machine or environment with ARM64 architecture support.
- Docker installed on your ARM64 system.
- 16261-16262 Udp ports open
- 27015 TCP port open (for steamcmd)

## Pulling from DockerHub

1. If using Podman

   ```bash
   podman pull docker.io/etheth888/project-zomboid-arm64:main
   ```

2. Otherwise

   ```bash
   docker pull etheth888/project-zomboid-arm64:main
   ```

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
   docker build -t project-zomboid-arm64:main .
   ```

   This command will build the Docker image named "project-zomboid-arm64"

## Running the Project Zomboid Docker Container

Once you've built or pulled the Docker image, you can run the container using the following steps:

1. Run the Project Zomboid container:

   ```bash
   docker run -it --name zomboid-server -p 16261:16261/udp -p 16262:16262/udp -p 27015:27015/tcp project-zomboid-arm64:main
   ```

   This command starts an interactive session inside the container.
   When you start the container the steamcmd runs and downloads Project Zomboid Dedicated Server automatically.
   The server is downloaded to /home/steam/Zomboid/

2. Start the server to generate server files

   ```bash
   FEXBash ./start-server.sh
   ```
3. Close the server and make changes you want in /home/steam/Zomboid/Server/

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

## If using Tmux

Running tmux is often better for long-running processes as you can access the container while the process is being run.

1. In the container run:

  ```bash
  tmux new -s Server
  ```

You can now start the server in the tmux window.

## Detach from session
  ```bash
  Ctrl + b, d
  ```

## Attach to session
  ```bash
  tmux a
  ```

With tmux you should be able to exit the docker container without detaching and without it closing.

## Enter exited Docker Container
  ```bash
  docker exec -it zomboid-server bash
  ```

## Additional Information

1. If you need to make modifications to the container the root password is: `steamcmd`.

- [DockerHub Image](https://hub.docker.com/r/etheth888/project-zomboid-arm64)
- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)
- [Docker Documentation](https://docs.docker.com/)
- [Tmux Quick Reference](https://tmuxcheatsheet.com)
