# Base image
FROM ubuntu:22.04

# Avoid interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Default environment variables
ENV TEAMSERVER_HOST=0.0.0.0
ENV TEAMSERVER_PASSWORD=changeme
ENV C2_PROFILE_NAME=reference.profile

# Expose necessary ports
EXPOSE 50050

# Install required packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      curl \
      netcat \
      expect \
      supervisor \
      gettext-base \
      openjdk-11-jdk && \
    rm -rf /var/lib/apt/lists/*

# Make OpenJDK 11 the default
#RUN update-java-alternatives -s java-1.11.0-openjdk-amd64
#RUN echo 'JAVA_HOME="/usr/local/jdk-11.0.1"' >> /etc/bashrc
#RUN echo 'PATH=$PATH:$JAVA_HOME/bin' >> /etc/bashrc

# Set up directories
WORKDIR /opt/cobaltstrike
RUN mkdir -p /opt/cobaltstrike/server /opt/cobaltstrike/client /opt/cobaltstrike/services /opt/cobaltstrike/scripts /var/log/supervisor
RUN chmod 755 /opt/cobaltstrike

# Copy scripts to the container
COPY scripts/* /opt/cobaltstrike/scripts/
RUN chmod +x /opt/cobaltstrike/scripts/*
#COPY scripts/install-teamserver.sh /opt/cobaltstrike/scripts/install-teamserver.sh
#COPY scripts/start-teamserver.sh /opt/cobaltstrike/scripts/start-teamserver.sh
#COPY scripts/start-listeners.sh /opt/cobaltstrike/scripts/start-listeners.sh
#RUN chmod +x /opt/cobaltstrike/scripts/install-teamserver.sh /opt/cobaltstrike/scripts/start-teamserver.sh /opt/cobaltstrike/scripts/start-listeners.sh

# Copy Cobalt Strike CNA templates to the container
COPY services/* /opt/cobaltstrike/services/
RUN chmod +x /opt/cobaltstrike/services/*

# Copy supervisord configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Use supervisord as the entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
