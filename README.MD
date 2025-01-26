# Cobalt Strike Docker Container

This repository provides a Docker container for running a Cobalt Strike Teamserver.

![alt text](image.png)

## Overview
Cobalt Strike is a Red Team post-exploitation framework. Likely, if you are here, you know what it is already. This project aims to make deployment of Cobalt Strike straightforward using Docker Compose.

### Features
- **Easy deployment**: Quickly spin up a Cobalt Strike Teamserver with Docker Compose.
- **Custom C2 profiles**: Load custom C2 profiles from the `./profiles` directory.
- **Auto-Start Listeners**: Preconfigure listeners via environment variables (HTTP/S, DNS, SMB).

## Installation

### Prerequisites
- Valid Cobalt Strike License: Replace LICENSE_KEY in docker-compose.yml.
- Open Ports: Ensure 50050 (Teamserver), 443 (HTTPS), 80 (HTTP), and 53/udp (DNS) are accessible on your Docker host.
- Some understanding of Cobalt Strike and how it works.

### Prepare Docker and Docker Compose plugin
- Install Docker and the Docker Compose plugin on your host. See:
    - [Install Docker Engine](https://docs.docker.com/engine/install/)
    - [Install Docker Engine](https://docs.docker.com/compose/install/)
- Ensure your host fulfils the minimum requirements the Teamserver, see the installation guide for details:
  - [Cobalt Strike Installation Guide](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/cobalt-strike-install.pdf)


### Prepare C2 profile
- Create a local directory to store your C2 profile in. This will later be mounted by docker.
  ```bash
  mkdir profiles
  ```
- If you haven't already, write or generate your C2 profile
- Place your C2 profile (e.g., `your_profile.profile`) in the `./profiles` directory.
- For a reference profile and guidance on how to write C2 profiles, see:
    - [Link to reference profile on github](https://github.com/Cobalt-Strike/Malleable-C2-Profiles/blob/master/normal/reference.profile)
    - [CS manual: Malleable Command and Control](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics/malleable-c2_main.htm?cshid=1062)

### Configure Environment
Edit or create your `docker-compose.yml` file and add your variables. Make sure the file exists in the same directory as the `profiles` directory, or change your path. Variables indicated with * are required.
```yaml
version: "3.8"
services:
  cobaltstrike:
    image: cobaltstrike
    container_name: cobaltstrike
    ports:
      - "50050:50050"          # Teamserver communication (*)
      - "443:443"              # HTTPS listener
      - "80:80"                # HTTP listener
      - "53:53/udp"            # DNS listener
    volumes:
      - ./profiles:/opt/cobaltstrike/profiles      # Host path to your C2 profile (*)
    environment:
      - LICENSE_KEY=your_license_key_here          # Replace with your valid license (*)
      - TEAMSERVER_PASSWORD=your_secure_password   # Team server password (*)
      - HTTPS_LISTENER_DOMAIN_NAME=example.com     # Your HTTPS listener domain name
      - HTTP_LISTENER_DOMAIN_NAME=example.com      # Your HTTP listener domain name
      - DNS_LISTENER_DOMAIN_NAME=c2.example.com    # Your DNS listener domain name
      - DNS_LISTENER_STAGER_DOMAIN_NAME=stager.example.com # Your DNS stager domain name (required field in CS, even if you don't use stagers)
      - SMB_LISTENER_NAMED_PIPE_NAME=pipe_name     # Your SMB named pipe name
    restart: unless-stopped
```

### Start the container with Docker compose
```bash
docker-compose up -d
```

The installation may take up to five minutes. If you cannot connect to the Teamserver or something else is wrong, check the troubleshooting section below.

### Verify deployment
```bash
docker ps -a | grep cobaltstrike  # Check container status
docker logs cobaltstrike          # View logs (Ctrl+C to exit)
```

### Manually verify listener with CS client
You can of course also connect to the Teamserver with your Cobalt Strike client.
- Connect via Cobalt Strike client
- Navigate to Cobalt Strike -> Listeners



## Configuration

### Modifying listeners
If you have already deployed it all, and later want to change your listeners, the best way is to change the environment variables in your compose file and restart the container.

### Manual Listener configuration
If you want to manually add listeners:
- Connect via Cobalt Strike client.
- Navigate to Cobalt Strike > Listeners.
- Add listeners as needed.

Note: If you do this, remove environment variables that configure listeners, otherwise your listeners will be overwritten on a container restart.

### Don't want to use Docker Compose?
You can turn the compose file into a Docker run command with [decomposerize](https://www.decomposerize.com/).

### Don't want to start any listeners automatically?
No worries, just delete or comment out all the environment variables with LISTENER in the name.  If you do this, it might be a good idea to also remove the port mappings you don't use.

WARNING: Do not remove the port mapping for 50050 as that will prevent you from connecting to your Teamserver.



## Troubleshooting

### Container immediately exits, keeps restarting or does not start at all
Verify status of the container
```bash
docker ps -a | grep cobaltstrike
```
Check the container logs
```bash
docker logs cobaltstrike
```
Try recreating the container (everything in the container will be lost!)
```bash
docker compose up -d --force-recreate
```
If this doesn't help, the image may be broken and I am sorry. Submit an issue with the log output and your compose file. Redact any sensitive information like your license key.

### Container runs, but nothing seems to be happening
The installation of Cobalt Strike takes a few minutes when it installs the first time. If you are curious about the status, you can check nspect the logs from Supervisor in the running container:
```bash
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/*'
```
If you don't know what is wrong or can't fix it, submit an issue with all the Supervisor logs.

### Can't connect to Teamserver
If you cannot connect to the Teamserver:
```bash
nc localhost 50050 -vz
```
Do you get a response? If not / connection refused, check logs
```bash
docker exec -it cobaltstrike /bin/bash -c 'cat /var/log/supervisor/*'
```

### No listeners are running
The answer is to check the logs:
```bash
tail -f /var/log/supervisor/*
```

### I just want to verify everything is working as it should
Verify Teamserver and listeners have started. From your Docker host, run:
```bash
nc localhost 50050 -vz 2>&1 | grep Connected
nc localhost 443 -vz 2>&1 | grep Connected
nc localhost 80 -vz 2>&1 | grep Connected
nslookup c2.example.com localhost
```
If everything is working, this should give you some kind of response like:
```
Ncat: Connected to 127.0.0.1:50050.
Ncat: Connected to 127.0.0.1:443.
Ncat: Connected to 127.0.0.1:80.
Server:         localhost
Address:        127.0.0.1#53

Non-authoritative answer:
Name:   c2.example.com
Address: 1.1.1.1
```

### Other frequent issues
- **Logs**: Check container logs with `docker logs cobaltstrike` or exec into a running container and inspect the logs from Supervisor: `docker exec -it cobaltstrike /bin/bash` followed by `tail -f /var/log/supervisor/*`
- **Teamserver IP address**: The Teamserver IP should normally be the same as the host. Since this runs in a container, it starts the Teamserver with the IP of the Docker container. This should not be a problem.
- **Port conflicts**: Ensure port `50050` is available on the Docker host. Normally not an issue, but sometimes you have accidentally spun up multiple containers.
- **Profile errors**: Verify your C2 profile has been installed in `./profiles` and has the .profile extension. Only one file is permitted and if you place multiple files it will choose the first one it finds. If you change the profile, you must restart the container for the changes to take effect.
- **Teamserver errors**: The following error is sometimes thrown in the Teamserver stdout logs. This is caused by the socket is closed after the script that starts the listeners logs in. You can safely ignore this.
    ```
    Trapped java.io.EOFException during client (127.0.0.1) read [Manage: svc]: null
    ```
  Another error sometimes occurs if you are trying to connect to the Teamserver with e.g. netcat locally. Nothing to worry about.
    ```
    [-] Trapped javax.net.ssl.SSLHandshakeException during could not authenticate client from 127.0.0.1 [accept client from 127.0.0.1 (auth phase)]: Remote host terminated the handshake
    ```

## Contributions
Contribute by submitting issues or pull requests.

### Modifying and building
#### Clone the Repository
```bash
git clone https://github.com/yourusername/cobaltstrike-docker.git
cd cobaltstrike-docker
```
Make any modification you like.

#### Build the image
```bash
docker build -t cobaltstrike:latest
```

## Security notes
- **Use strong credentials**: The default `TEAMSERVER_PASSWORD` is insecure—replace it.
- **Restrict access**: Expose the Teamserver and port `50050` only to trusted networks. (Read: Not The Internet)
- **Compliance**: Ensure you have proper licensing and authorization to use Cobalt Strike.


##  Disclaimer
- docker-cobaltstrike is licensed under 
- This project is intended for **legal and authorized use only**.
- Cobalt Strike is a commercial tool—ensure you have a valid license from [HelpSystems](https://www.helpsystems.com/).
- Maintainers are not responsible for misuse of this setup.


## License

The MIT License (MIT)

Copyright (c) 2015 Chris Kibble

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## How it works
If you are really interested in the details, I have documented how this works to the best of my abilities in this section.

### Challenges
Designing this came with two major challenges:
- Cobalt Strike must be downloaded from a web page and installed with hands-on keyboard
- Ideally a container only does "one thing" / or runs one process, but this project does three:
  - Download and install the Teamserver 
  - Start the Teamserver
  - Start the listeners

### How its implemented
#### Dockerfile
This is largely self-explanatory:
- Based on Ubuntu 22.04
- Sets some sane defaults for ENV vars in case the user does not
- Installs software dependencies
- Prepares the CS install directory to /opt/cobaltstrike
- Copies the installation scripts to the container image
- Copies the Supervisor config to the container image
- Sets Supervisor as the entrypoint

#### When the container starts
The container runs [Supervisor](https://supervisord.org/), which reads `supervisord.conf`. This configuration takes care of everything that happens when the container starts. The actual jobs are bash scripts triggered by Supervisor that do the following: 
  - **Installation**: Check if the Teamserver is installed already. If not, install the Teamserver.
  - **Start Teamserver**: Check if the Teamserver has been successfully installed. If so, it looks up the first C2 profile it finds in the `profiles` directory and starts the Teamserver. Supervisor takes care of making sure this one auto-restart if it crashes (shouldn't happen) and when the container restarts.
  - **Start listeners**: Check if the Teamserver responds on port 50050. If so, start the listeners.

Note however that Supervisor doesn't really support handling dependencies between jobs like we have here. In the supervisord.conf therefore contains 

#### The Teamserver install script
To deal with the first challenge, a somehow robust bash script acts as a wrapper around the Cobalt Strike installation process, with lots of error handling. This is the `install-teamserver.sh` script, which does the following:
- Check if license key is on disk, if not:
  - Write the supplied license key to disk
- Check if CS is installed already, if not:
  - Use the license key to retrieve a download token and what the latest version of CS is
  - Use the download token and version information to download an archive file containing the latest version of CS
  - Unarchive the file to the CS install directory
- Run the CS update script and pipe the license file to its input
- Perform a final check to see if the installation was successful and write a flag that indicates this.

#### The Teamserver starting script
This script is simple:
- Loops over the `profiles` directory and identifies the first file it finds with the `.profile` extension
- Starts the teamserver using the environment variables (like password) and the mounted C2 profile

#### The start listener script
This process uses aggressor scripts (CNA) to automate starting listeners. There is one CNA script for each listener type configured according to the environment variables specified in the Docker config. The script does the following:
- Loops over each CNA script template in the `scripts` directory and does the following:
  - Replaces the variables of each template using the tool `envsubst`
  - Uses CS `agscript` to connect to the Teamserver and run the CNA script 

For documentation on how the listeners are created, see:
- [CS manual: listener_create_ext](https://hstechdocs.helpsystems.com/manuals/cobaltstrike/current/userguide/content/topics_aggressor-scripts/as-resources_functions.htm#listener_create_ext)
- [CS blog: Create listeners with an aggressor script - listener_create_ext](https://www.cobaltstrike.com/blog/create-listeners-with-an-aggressor-script-listener_create_ext)

If you are curious, I recommend reading the source code for the Dockerfile, supervisord.conf, the bash scripts and cna templates to see how it all fits together.

### Design considerations
Here are some considerations and choices I made for this project.
#### Installing the Teamserver in the container / Dockerfile
This apporach would require me to either hardcode my license, which is completely out of the question, or supply a build time argument when building the container. The latter works, but would not allow me to publish the container nonetheless as it would be licensed with my license. Essentially, to use this project, you would have to build the container yourself and license it. That may be useful to some, but was not the goal of this project.
#### Not starting listeners
I could have built the project without starting any listeners. This would have been more than ok and removed a bit of complexity from the project. However, I had already experimented quite a bit with starting listeners through aggressor scripts, which means it was not too bad to get this working. You can also simply delete the environment variables and no 
#### Handling everything with Bash
I tried, and failed miserably. The one `entrypoint.sh` script I used to both install, run the Teamserver and start the listeners. And this absolutely breaks with the "one process" paradigm of Docker containers. Supervisor gave me a much more robust and flexible way to deal with the dependent tasks.

### Known limitations
- **No TLS certificate installed**: This project does not configure a TLS certificate for the HTTPS listener. If you choose to start an HTTPS listener it will start with the default certificate. For some operators this is not a problem if they for example terminate TLS on their redirector. Feel free to submit a pull request if you feel like implementing support for this.
- **Listener options**: This projects does a rudimentary job at starting listeners for you and should have sane defaults. You can see what they are in the CNA templates in `./services/`. Not every single listener configuration is currently supported. If you need more flexibility, remove all the listener specific environment variables. That will ensure no listeners are created so you can create your own listeners in the GUI. Alternatively, rewrite the CNA scripts to support more functionality and submit a pull request.

