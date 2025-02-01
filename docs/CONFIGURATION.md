# Configuration Guide

## Environment Variables

### Required Variables

#### TEAMSERVER_PASSWORD
- **Description**: Password for the Cobalt Strike team server
- **Format**: Minimum 8 characters
- **Example**: `TEAMSERVER_PASSWORD=your_secure_password`
- **Security Note**: Choose a strong password, avoid defaults

#### LICENSE_KEY
- **Description**: Your Cobalt Strike license key
- **Format**: Alphanumeric with hyphens
- **Example**: `LICENSE_KEY=XXXX-YYYY-ZZZZ`
- **Note**: Must be a valid, active license

#### C2_PROFILE_NAME
- **Description**: Name of your C2 profile file
- **Format**: Must end in .profile
- **Example**: `C2_PROFILE_NAME=custom.profile`
- **Location**: Must exist in mounted profiles directory

### Optional Listener Variables

#### HTTPS_LISTENER_DOMAIN_NAME
- **Description**: Domain for HTTPS C2 communication
- **Format**: Valid domain name
- **Example**: `HTTPS_LISTENER_DOMAIN_NAME=example.com`
- **Port**: Uses 443 by default

#### HTTP_LISTENER_DOMAIN_NAME
- **Description**: Domain for HTTP C2 communication
- **Format**: Valid domain name
- **Example**: `HTTP_LISTENER_DOMAIN_NAME=example.com`
- **Port**: Uses 80 by default

#### DNS_LISTENER_DOMAIN_NAME
- **Description**: Domain for DNS C2 communication
- **Format**: Valid domain name
- **Example**: `DNS_LISTENER_DOMAIN_NAME=c2.example.com`
- **Port**: Uses 53/udp by default

#### SMB_C2_NAMED_PIPE_NAME
- **Description**: Named pipe for SMB listener
- **Format**: Alphanumeric with dots, underscores, hyphens
- **Example**: `SMB_C2_NAMED_PIPE_NAME=custom_pipe`

## Docker Compose Configuration

### Basic Configuration
```yaml
version: "3.8"
services:
  cobaltstrike:
    image: chryzsh/cobaltstrike
    container_name: cobaltstrike
    ports:
      - "50050:50050"  # Required: Teamserver
    volumes:
      - ./profiles:/opt/cobaltstrike/profiles  # Required: C2 profiles
    environment:
      - TEAMSERVER_PASSWORD=your_secure_password
      - LICENSE_KEY=your-license-key
      - C2_PROFILE_NAME=your.profile
    restart: unless-stopped
```

### Full Configuration with Listeners
```yaml
version: "3.8"
services:
  cobaltstrike:
    image: chryzsh/cobaltstrike
    container_name: cobaltstrike
    ports:
      - "50050:50050"  # Teamserver
      - "443:443"      # HTTPS listener
      - "80:80"        # HTTP listener
      - "53:53/udp"    # DNS listener
    volumes:
      - ./profiles:/opt/cobaltstrike/profiles
      - ./logs:/var/log/supervisor
    environment:
      # Required
      - TEAMSERVER_PASSWORD=your_secure_password
      - LICENSE_KEY=your-license-key
      - C2_PROFILE_NAME=your.profile
      # Optional Listeners
      - HTTPS_LISTENER_DOMAIN_NAME=example.com
      - HTTP_LISTENER_DOMAIN_NAME=example.com
      - DNS_LISTENER_DOMAIN_NAME=c2.example.com
      - SMB_C2_NAMED_PIPE_NAME=custom_pipe
    restart: unless-stopped
```

## Volume Mounts

### Profiles Directory
- **Path**: `./profiles:/opt/cobaltstrike/profiles`
- **Required**: Yes
- **Contents**: Your C2 profile files
- **Note**: Must contain the profile specified in C2_PROFILE_NAME

### Logs Directory
- **Path**: `./logs:/var/log/supervisor`
- **Required**: No, but recommended
- **Contents**: Supervisor and service logs
- **Purpose**: Troubleshooting and monitoring

## Port Mappings

### Required Ports
- **50050**: Teamserver communication
  - Required for client connections
  - Must be exposed

### Optional Ports (Listener Dependent)
- **443**: HTTPS listener
- **80**: HTTP listener
- **53/udp**: DNS listener

## Security Considerations

### Password Security
- Use strong passwords for TEAMSERVER_PASSWORD
- Avoid default or easily guessable passwords
- Consider using environment files instead of docker-compose.yml

### Network Security
- Limit access to port 50050 to trusted networks
- Consider using VPN or SSH tunnels for remote access
- Use proper certificates in production for HTTPS

## Advanced Configuration

### Custom Certificates
For production HTTPS listeners:
1. Mount certificate files
2. Update C2 profile accordingly
3. Consider terminating TLS at redirector

### Multiple Profiles
To manage multiple profiles:
1. Place all profiles in mounted directory
2. Switch profiles by updating C2_PROFILE_NAME
3. Restart container to apply changes