# Architecture Documentation

## Overview
This document details the technical architecture of the Docker Cobalt Strike container implementation.

## Core Components

### Container Structure
- Based on Ubuntu 22.04
- Uses Supervisor for process management
- Four main processes: installation, teamserver, listeners, and REST API

### Process Management
- Supervisor manages process dependencies and lifecycle
- Enhanced error handling and recovery
- Process state monitoring and logging
- Parallel listener setup

### Environment Validation
- Centralized validation for all variables
- Required variables:
  - TEAMSERVER_PASSWORD
  - LICENSE_KEY
  - C2_PROFILE_NAME (optional — falls back to first .profile found)
- Optional listener configurations
- Regex-based format validation

## Implementation Details

### Installation Process
- License verification
- Download token retrieval
- Automated installation
- Installation state management

### Teamserver Management
- Internal communication via localhost
- C2 profile validation and loading
- Process monitoring and recovery
- Error handling and logging

### Listener Management
- Parallel listener setup
- Individual error handling per listener
- Templated CNA scripts
- Automatic retry mechanisms

### REST API
- Available on port 50443 (Cobalt Strike 4.12+)
- Connects to teamserver on localhost:50050
- Authenticates with TEAMSERVER_PASSWORD using a dedicated `csrestapi` user
- Waits for teamserver port to be available before starting
- Managed by supervisord with auto-restart

## Design Decisions

### Container Communication
- Internal services use localhost (127.0.0.1)
- External access through Docker port mapping
- Clear separation of internal/external communication

### Error Handling Strategy
- Comprehensive validation before operations
- Retry mechanisms for critical operations
- Detailed logging for troubleshooting
- Proper cleanup on failures

### Configuration Management
- Required vs optional configuration
- No default sensitive values
- Clear validation rules
- Explicit requirements