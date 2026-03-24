# Code Review Improvements Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Address code quality issues found during codebase review without breaking existing functionality.

**Architecture:** Targeted fixes to existing files — no structural changes to the startup sequence or process management.

**Tech Stack:** Bash, Docker, supervisord, Aggressor CNA scripts

---

## Quick Wins (do now)

### Task 1: Fix http-listener.cna.template copy-paste bug
- **Status:** DONE (cad3652)
- **File:** `services/http-listener.cna.template:17`
- **Issue:** Prints "HTTPS Listener created" instead of "HTTP Listener created"
- **Fix:** Removed stray duplicate println line

### Task 2: Standardize CNA template sleep times
- **Status:** DONE (b91a47b)
- **Files:** `services/dns-listener.cna.template`, `services/https-listener.cna.template`, `services/http-listener.cna.template`
- **Issue:** DNS/HTTP/HTTPS use `sleep(1000)` but SMB uses `sleep(3000)`. Short sleep risks disconnecting before listener is confirmed.
- **Fix:** All templates now use `sleep(3000)`

### Task 3: Replace eval in start-listeners.sh get_env_var()
- **Status:** DONE (82cdde4)
- **File:** `scripts/start-listeners.sh:25-28`
- **Issue:** `eval echo "\${$var_name:-}"` — unnecessary use of eval, can be replaced with bash indirect expansion
- **Fix:** Replaced with `echo "${!var_name:-}"`

### Task 4: Add .dockerignore
- **Status:** DONE (4ff39a7)
- **File:** `.dockerignore` (created)
- **Issue:** No .dockerignore means .git/, docs/, images, markdown files all get sent to Docker build context
- **Fix:** Created .dockerignore excluding .git, .github, docs, *.md, image.png, profiles, *.yml, *.log

### Task 5: Add HEALTHCHECK to Dockerfile
- **Status:** DONE (748db90)
- **File:** `Dockerfile`
- **Issue:** No health check — orchestration tools can't detect if teamserver is actually running
- **Fix:** Added HEALTHCHECK: `nc -z localhost 50050` every 30s, 120s start period

---

## Medium Effort (do later)

### Task 6: Add version tagging to CI
- **Status:** SKIPPED — user prefers `:latest` only, no need for rollback tags

### Task 7: Extract duplicate IP detection to shared function
- **Status:** DONE (f25ee50)
- **Files:** `scripts/start-teamserver.sh`, `scripts/start-listeners.sh`, `scripts/env_validator.sh`
- **Issue:** `hostname -I | awk '{print $1}'` duplicated with identical error handling
- **Fix:** Added `get_container_ip()` to env_validator.sh, both scripts now use it

### Task 8: Fix C2_PROFILE_NAME env var inconsistency
- **Status:** DONE (2d9a7af)
- **Files:** `scripts/start-teamserver.sh`
- **Issue:** C2_PROFILE_NAME is documented as required but start-teamserver.sh ignores it and just picks the first .profile file
- **Fix:** Implemented C2_PROFILE_NAME support — uses specific profile if set, falls back to first .profile found

### Task 9: Add log rotation
- **Status:** SKIPPED — containers are redeployed frequently, not a practical issue

### Task 10: Update ARCHITECTURE.md for REST API
- **Status:** DONE (32c6618)
- **File:** `docs/ARCHITECTURE.md`
- **Issue:** No mention of REST API feature added in recent commits
- **Fix:** Added REST API section, corrected C2_PROFILE_NAME as optional
