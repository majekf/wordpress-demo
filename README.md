# WordPress 7 Docker Compose Setup

## Quick Start

1. **Start the containers:**
   ```powershell
   docker compose up -d
   ```
   Or use the startup script:
   ```powershell
   .\startup.ps1
   ```

2. **Wait for services to be ready** (about 30 seconds)

3. **Access WordPress:**
   - Navigate to: http://localhost:8080
   - Database will be automatically created and configured

## Initial WordPress Setup

When you first access http://localhost:8080, you'll see the WordPress installation wizard. Complete the setup with:

- **Site Language:** English (or your preference)
- **Site Title:** Your site name
- **Username:** admin (or your preferred admin username)
- **Password:** Create a strong password
- **Email:** Your email address

## Credentials Reference

**Database Connection (for reference):**
- Host: db (or db:3306 from outside container)
- Database: wordpress
- User: wordpress
- Password: wordpresspass123
- Root Password: rootpassword123

**Access Points:**
- WordPress Site: http://localhost:8080
- WordPress Admin: http://localhost:8080/wp-admin
- MySQL Host: localhost:3306 (if using MySQL client)

## Useful Commands

```powershell
# View logs
docker compose logs -f wordpress

# Stop containers
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v

# Access WordPress container shell
docker exec -it wordpress-app bash

# Access MySQL container
docker exec -it wordpress-db mysql -u wordpress -p
# Then enter password: wordpresspass123
```

## Troubleshooting

- **Can't access WordPress:** Wait 30 seconds and ensure all containers are running (`docker compose ps`)
- **Database connection error:** Check that the `db` container is healthy (`docker compose logs db`)
- **docker-compose command not found:** Use `docker compose` (new syntax) instead of `docker-compose` (old standalone tool)
- **Port already in use:** Change port 8080 in docker-compose.yml or stop other services

## Rancher Desktop Notes

- Ensure Rancher Desktop is running and Docker is enabled
- The setup will work with the default Rancher Desktop configuration
- Volumes persist data between restarts
