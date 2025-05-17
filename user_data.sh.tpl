#!/bin/bash
# Update packages and install prerequisites
apt-get update -y
apt-get install -y docker.io nginx git curl nodejs npm

# Install Yarn globally
npm install -g yarn

# Add the 'ubuntu' user to the docker group
usermod -aG docker ubuntu

# Start Docker service and enable it on boot
systemctl start docker
systemctl enable docker

# Deploy Backend Container (always deployed)
docker pull ${backend_image}
docker stop ${backend_container_name} || true
docker rm ${backend_container_name} || true
docker run -d --name ${backend_container_name} -p ${backend_port}:${backend_port} ${backend_image}

# Conditionally deploy Front-End Container if front_end_image is provided
if [ -n "${front_end_image}" ]; then
    docker pull ${front_end_image}
    docker stop ${front_end_container_name} || true
    docker rm ${front_end_container_name} || true
    docker run -d --name ${front_end_container_name} -p ${front_end_port}:${front_end_port} ${front_end_image}
fi

# Determine server name: if dns_name is provided, use it; otherwise, get the EC2 public IP from metadata
if [ -z "${dns_name}" ]; then
  server_name=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
else
  server_name=${dns_name}
fi

# Write Nginx configuration for HTTP only
cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:${backend_port}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:${backend_port}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:${front_end_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

systemctl restart nginx

# Run Certbot only if dns_name is provided
if [ ! -z "${dns_name}" ]; then
  certbot --nginx --non-interactive --agree-tos --email ${certbot_email} -d ${dns_name}
fi
