#!/bin/bash
set -euo pipefail

# Start Apache in the background
echo "Starting Apache..."
/usr/local/bin/docker-entrypoint.sh apache2-foreground &
APACHE_PID=$!

# Wait for WordPress files and MySQL readiness
echo "Waiting for WordPress files to be copied and MySQL to be ready..."
sleep 45

# Check and install WordPress if needed
if ! wp core is-installed --allow-root 2>/dev/null; then
    echo "Installing WordPress with admin credentials..."
    wp core install \
        --url="http://localhost:8080" \
        --title="My WordPress Site" \
        --admin_user="admin" \
        --admin_password="Admin123!@#" \
        --admin_email="admin@localhost.local" \
        --allow-root \
        --skip-email
    echo ""
    echo "✓✓✓ WordPress installed successfully! ✓✓✓"
    echo ""
    echo "Admin Login Credentials:"
    echo "  Username: admin"
    echo "  Password: Admin123!@#"
    echo ""
    echo "Access WordPress at: http://localhost:8080"
else
    echo "✓ WordPress is already installed"
fi

# Keep Apache running
wait "$APACHE_PID"
