#!/bin/bash
# Script to update Nginx configuration with subdomain-based routing
# Usage: ./update_nginx.sh [backend_port] [frontend_port]

# Get backend and frontend ports from arguments or use defaults
BACKEND_PORT=${1:-8080}  # Default to 8080 as confirmed working for backend
FRONTEND_PORT=${2:-3000}  # Adjust frontend port as needed

echo "Updating Nginx configuration..."
echo "Backend port: $BACKEND_PORT"
echo "Frontend port: $FRONTEND_PORT"

# Create new Nginx configuration
cat > /tmp/nginx_config << EOF
# API subdomain server block - all traffic goes directly to backend
server {
    listen 80;
    listen [::]:80;
    server_name api.amygdalas.com staging.api.amygdalas.com;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # All other traffic goes to backend, without the /api/ prefix
    location / {
        proxy_pass http://127.0.0.1:$BACKEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# Main website server block - uses path-based routing
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name amygdalas.com www.amygdalas.com _;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API endpoints still accessible through path-based routing
    location /api/ {
        proxy_pass http://127.0.0.1:$BACKEND_PORT/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:$FRONTEND_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Back up existing configuration
if [ -f /etc/nginx/sites-available/default ]; then
    echo "Backing up existing Nginx configuration..."
    sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak.$(date +%Y%m%d%H%M%S)
fi

# Update Nginx configuration
echo "Installing new Nginx configuration..."
sudo cp /tmp/nginx_config /etc/nginx/sites-available/default

# Test configuration
echo "Testing Nginx configuration..."
sudo nginx -t
if [ $? -ne 0 ]; then
    echo "Error: Nginx configuration test failed."
    echo "Restoring previous configuration..."
    sudo cp $(ls -t /etc/nginx/sites-available/default.bak.* | head -1) /etc/nginx/sites-available/default
    sudo systemctl restart nginx
    exit 1
fi

# Restart Nginx to apply changes
echo "Restarting Nginx..."
sudo systemctl restart nginx
if [ $? -ne 0 ]; then
    echo "Error: Failed to restart Nginx."
    exit 1
fi

# Clean up
rm /tmp/nginx_config

echo "Nginx configuration updated successfully!"
echo "You can verify the changes by checking: sudo nginx -T | grep server_name"
