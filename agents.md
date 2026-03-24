# LLM Agent Guidelines for docker-cobaltstrike

## Project Overview

Docker container for deploying a Cobalt Strike Teamserver. Uses supervisord to orchestrate installation, teamserver startup, listener configuration, and REST API services. The Docker image is published to Docker Hub as `chryzsh/cobaltstrike:latest` via GitHub Actions CI.

This is a **red team infrastructure** project. All code changes must be evaluated through the lens of operational security and reliability — a broken teamserver during an engagement is a critical failure.

## Repository Structure

```
Dockerfile                  # Ubuntu 22.04 base, Java 17, supervisord entrypoint
supervisord.conf            # Process orchestration (installer -> teamserver -> listeners/restapi)
scripts/
  env_validator.sh          # Shared env var validation (sourced by all scripts)
  install-teamserver.sh     # Downloads/installs CS, creates installer_done.flag
  start-teamserver.sh       # Waits for install, validates prereqs, launches teamserver
  start-listeners.sh        # Parallel listener setup via agscript + CNA templates
  start-restapi.sh          # Starts CS REST API (connects to teamserver on localhost:50050)
  state_monitor.sh          # Supervisord event listener for process state changes
services/
  *-listener.cna.template   # Aggressor script templates (envsubst'd at runtime)
.github/workflows/
  docker-image.yml          # CI: build + push to Docker Hub on push/PR/schedule/dispatch
docs/                       # Configuration, architecture, troubleshooting guides
```

## Startup Sequence

Supervisord launches all processes simultaneously, but dependencies are enforced with wait loops:

1. **cs_installer** (priority 1): Validates env, writes license, downloads/installs CS, creates `installer_done.flag`
2. **teamserver** (priority 2): Waits for `installer_done.flag`, then starts teamserver on port 50050
3. **listener** (priority 3): Waits for port 50050, then runs agscript to create listeners in parallel
4. **restapi** (priority 4): Waits for port 50050, then starts REST API on port 50443
5. **state_monitor**: Event listener that logs process state changes and kills supervisord if the installer fails

## Key Design Patterns

- **All scripts source `env_validator.sh`** for consistent environment validation
- **CNA templates** use `envsubst` for variable substitution — the templates in `services/` use `${VAR}` syntax
- **Listeners are optional** — they only start if their corresponding env var is set
- **The installer creates a flag file** (`installer_done.flag`) to signal the teamserver to start
- **Pre-staged tarball support**: Mount `cobaltstrike-dist-linux.tgz` to `/opt/cobaltstrike/dist/` to skip the download (Cloudflare blocks automated downloads from `download.cobaltstrike.com`)

## Rules for Code Changes

### Shell Scripts
- All scripts use `set -euo pipefail` — do not remove this
- Use `retry_operation()` pattern for operations that contact external services
- Never hardcode license keys, passwords, or domain names — these come from env vars
- When adding new env vars: add validation to `env_validator.sh`, document in `docs/CONFIGURATION.md`
- The container runs as root (supervisord requirement) — be mindful of file permissions

### CNA Templates
- Templates live in `services/` with `.template` extension
- Variables use `${ENV_VAR}` syntax for `envsubst`
- Generated `.cna` files are gitignored
- Each template must call `closeClient()` after setup to release the agscript connection

### Dockerfile
- Keep the image minimal — `--no-install-recommends` on all apt packages
- Clean up apt lists after install (`rm -rf /var/lib/apt/lists/*`)
- Don't add build tools or compilers — this is a runtime-only image

### Supervisord
- Process priority numbers matter — lower numbers start first
- The teamserver and listeners use bash wait loops for dependency management, not supervisord's built-in dependency system
- `cs_installer` uses `autorestart=unexpected` with `exitcodes=0` — it should run once and succeed
- Other services use `autorestart=true` to survive transient failures

### CI/CD
- The GitHub Actions workflow builds and pushes to Docker Hub on every push to `main`
- The workflow can be disabled by GitHub after 60 days of inactivity
- `workflow_dispatch` trigger is available for manual builds
- Requires `DOCKERHUB_USERNAME` (var) and `DOCKERHUB_TOKEN` (secret) configured in the repo

## Git Workflow

- **Do not push to `main` unless intentional** — every push triggers a Docker image rebuild and publish via GitHub Actions. Batch changes into meaningful commits and push when ready.
- Commit freely, but treat `git push` as a deploy action.

## What NOT to Do

- Don't add interactive prompts — everything runs unattended in a container
- Don't add `docker-compose.yml` to the repo — it's gitignored because it contains secrets; examples go in README/docs
- Don't commit `.cna` files — only `.cna.template` files belong in the repo
- Don't modify the supervisord entrypoint to anything other than supervisord — it manages all process lifecycle
- Don't add `sleep` as a substitute for proper wait-loop dependency checks
- Don't expose additional ports in the Dockerfile without documenting them
- Don't write secrets or license keys to logs

## Testing Changes

There is no automated test suite. To test changes:

1. Build the image locally: `docker build -t cobaltstrike:test .`
2. Run with required env vars and a mounted C2 profile
3. Check `logs/supervisord.log` for process startup sequence
4. Check individual service logs (`cs_installer.out.log`, `teamserver.out.log`, etc.)
5. Verify teamserver accepts connections on port 50050
6. Verify REST API responds on port 50443 (if configured)
