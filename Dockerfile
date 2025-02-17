# Base image
FROM ubuntu:22.04

# Avoid interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Required environment variables that must be provided at runtime:
# - TEAMSERVER_PASSWORD: Password for the team server (min 8 characters)
# - LICENSE_KEY: Your Cobalt Strike license key
# Note: A C2 profile file (*.profile) must be mounted in /opt/cobaltstrike/profiles

# Optional environment variables for listeners:
# - DNS_LISTENER_DOMAIN_NAME: Domain name for DNS listener
# - DNS_LISTENER_STAGER_DOMAIN_NAME: Domain name for DNS stager
# - HTTPS_LISTENER_DOMAIN_NAME: Domain name for HTTPS listener
# - HTTP_LISTENER_DOMAIN_NAME: Domain name for HTTP listener
# - SMB_LISTENER_NAMED_PIPE_NAME: Named pipe for SMB listener

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

# Set up directories
WORKDIR /opt/cobaltstrike
RUN mkdir -p /opt/cobaltstrike/server /opt/cobaltstrike/client /opt/cobaltstrike/services /opt/cobaltstrike/scripts /var/log/supervisor
RUN chmod 755 /opt/cobaltstrike

# Copy scripts to the container
COPY scripts/* /opt/cobaltstrike/scripts/
RUN chmod +x /opt/cobaltstrike/scripts/*

# Copy Cobalt Strike CNA templates to the container
COPY services/* /opt/cobaltstrike/services/
RUN chmod +x /opt/cobaltstrike/services/*

# Copy supervisord configuration
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Use supervisord as the entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
