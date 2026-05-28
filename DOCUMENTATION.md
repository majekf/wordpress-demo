# WordPress 7 Docker Setup - Development & Implementation Guide

## Problem Statement

The goal was to create a minimal Docker Compose setup that:
- Deploys WordPress 7 with MySQL 8.0 on Rancher Desktop
- Exposes WordPress on `localhost:8080`
- **Pre-configures WordPress with admin credentials (admin / Admin123!@#)**
- **Eliminates the WordPress setup wizard entirely**
- Can be executed from VS Code terminal with automatic admin privilege elevation

## Solution Evolution

### Initial Approach (Failed)
The first attempt used the standard `wordpress:7-apache` Docker image with a shell-based entrypoint containing `wp-cli` commands:

```bash
entrypoint: |
  sh -c '
  docker-entrypoint.sh apache2-foreground &
  sleep 45
  if ! wp core is-installed --allow-root 2>/dev/null; then
    wp core install ...
  fi
  wait
  '
```

**Problem:** The `wp-cli` binary is not included in the standard WordPress image, so installation silently failed and the setup wizard appeared.

### Root Cause Analysis
- WordPress base images don't include `wp-cli` by default
- Shell-based entrypoints fail silently when required binaries are missing
- The setup wizard appears whenever WordPress detects it's not installed

### Final Solution (Successful)
**Create a custom Dockerfile** that extends `wordpress:7-apache` and adds `wp-cli`:

```dockerfile
FROM wordpress:7-apache

# Install wp-cli
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp

# Copy initialization script
COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]
CMD ["apache2-foreground"]
```

This ensures `wp-cli` is available during initialization.

## Final Implementation

### Key Components

#### 1. **Dockerfile** (Custom Image)
Extends the official WordPress image with `wp-cli` installation. This is the critical piece that enables automated WordPress installation.

#### 2. **entrypoint.sh** (Initialization Script)
Runs when the container starts:
1. Starts Apache in the background
2. Waits for WordPress files and MySQL to initialize
3. Checks if WordPress is already installed
4. If not, runs `wp core install` with pre-configured admin credentials
5. Keeps Apache running

**Timing Strategy:** 50-second wait ensures WordPress files are copied and database is ready before installation attempts.

#### 3. **docker-compose.yml**
Defines two services:
- **db:** MySQL 8.0 with health checks
- **wordpress:** Custom WordPress image (built from Dockerfile)

Uses environment variables from `.env` for credentials.

#### 4. **.env**
Stores sensitive database credentials:
```
MYSQL_ROOT_PASSWORD=rootpassword123
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=wordpresspass123
```



## Execution Flow

```
1. User runs: docker-compose up -d
   ↓
2. Docker builds custom image (first time only)
   ↓
3. WordPress container starts with entrypoint.sh
   ↓
4. entrypoint.sh:
   - Starts Apache (background)
   - Waits 50 seconds for initialization
   - Installs WordPress with wp core install
   - Displays credentials
   - Keeps Apache running
   ↓
5. User accesses http://localhost:8080/wp-admin
   ↓
6. WordPress is already configured, login with:
   Username: admin
   Password: Admin123!@#
```

## Quick Start

```powershell
# Navigate to project directory
cd c:\Users\arath\git_projects\wordpress-demo

# Start containers (choose one)
.\startup.bat
# OR
docker-compose up -d

docker-compose up -d

# Wait ~90 seconds for WordPress installation and
# Password: Admin123!@#
```

## Why This Works

1. **Custom Dockerfile** solves the core problem: `wp-cli` is available
2. **Proper wait time** (50 seconds) ensures WordPress files are ready
3. **wp core install** with `--allow-root` flag works in Docker
4. **Entrypoint script** provides clear logging of what's happening
5. **Health checks** on MySQL ensure database is ready before WordPress tries to connect

## Commands for Development

```powershell
# View WordPress logs
docker-compose logs -f wordpress

# View MySQL logs
docker-compose logs -f db

# Shell into WordPress container
docker exec -it wordpress-app bash

# Rebuild image (after Dockerfile changes)
docker-compose build --no-cache

# Clean restart (removes containers and volumes)
docker-compose down -v
docker-compose up -d

# Check service status
docker-compose ps
```

## Key Learnings

1. **Docker base images often don't include CLI tools** - Sometimes you need to build a custom image
2. **Silent failures in entrypoints are hard to debug** - Always check `docker-compose logs`
3. **Timing matters in initialization** - Need adequate wait time for MySQL and WordPress files
4. **wp-cli is the standard tool** - It's worth installing it rather than trying complex SQL approaches
5. **Entrypoint logging is critical** - Clear messages help understand what's happening

## Successful Outcomes

✅ WordPress 7 running on Rancher Desktop  
✅ Pre-configured admin account (admin / Admin123!@#)  
✅ Setup wizard eliminated entirely  
✅ Accessible at http://localhost:8080 
✅ Database persists across restarts  
✅ Clean, maintainable Docker setup  
