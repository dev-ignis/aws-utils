#!/bin/bash
# Update packages and install prerequisites
apt-get update -y
apt-get install -y docker.io nginx certbot python3-certbot-nginx git curl nodejs npm

# Install Yarn globally
npm install -g yarn

# Deploy Backend Container (always deployed)
docker pull ${backend_image}
docker stop ${backend_container_name} || true
docker rm ${backend_container_name} || true
docker run -d --name ${backend_container_name} -p ${backend_port}:${backend_port} ${backend_image}

# Conditionally deploy Front-End Container only if front_end_image is provided
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

# Write Nginx configuration
cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name \$\{server_name};

    # If front_end_image is provided, serve the front end as default; otherwise, route to backend
    location / {
        proxy_pass http://127.0.0.1:$([ -n "${front_end_image}" ] && echo ${front_end_port} || echo ${backend_port});
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health checks to backend
    location /health {
        proxy_pass http://127.0.0.1:${backend_port}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /ask-specialist {
        proxy_pass http://localhost:8080/chatgpt;
    }

    location /specifics-list {
        proxy_pass http://localhost:8080/concern;
    }

    location /swagger/ {
        proxy_pass http://127.0.0.1:${backend_port}/swagger/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /users {
        proxy_pass http://127.0.0.1:${backend_port}/users;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

systemctl restart nginx

# Run Certbot only if a dns_name is provided
if [ ! -z "${dns_name}" ]; then
  certbot --nginx --non-interactive --agree-tos --email ${certbot_email} -d ${dns_name}
fi
