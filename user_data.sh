#!/bin/bash
apt-get update -y
apt-get install -y docker.io nginx certbot python3-certbot-nginx
usermod -aG docker ubuntu
systemctl start docker
systemctl enable docker
docker pull ${docker_image}
docker stop ${app_container_name} || true
docker rm ${app_container_name} || true
docker run -d --name ${app_container_name} -p ${app_port}:${app_port} ${docker_image}

# Determine server name: if dns_name is provided, use it; otherwise, get the EC2 public IP from metadata
if [ -z "${dns_name}" ]; then
  server_name=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
else
  server_name=${dns_name}
fi

cat > /etc/nginx/sites-available/default << EOL
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $${server_name};

    location / {
        proxy_pass http://127.0.0.1:${app_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:${app_port}/health;
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
        proxy_pass http://127.0.0.1:${app_port}/swagger/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /users {
        proxy_pass http://127.0.0.1:${app_port}/users;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

systemctl restart nginx

# Run Certbot only if a dns_name was provided
if [ ! -z "${dns_name}" ]; then
  certbot --nginx --non-interactive --agree-tos --email ${certbot_email} -d ${dns_name}
fi
