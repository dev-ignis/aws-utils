#!/bin/bash
apt-get update -y
apt-get install -y docker.io nginx certbot python3-certbot-nginx
usermod -aG docker ubuntu
systemctl start docker
systemctl enable docker
docker pull ${docker_image}
docker stop site_spidey_app || true
docker rm site_spidey_app || true
# Run the container exposing port 5000 internally
docker run -d --name site_spidey_app -p 5000:5000 ${docker_image}

# Configure NGINX to reverse proxy HTTP to the Docker container
cat > /etc/nginx/sites-available/default << 'EOL'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${dns_name};

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $$host;
        proxy_set_header X-Real-IP $$remote_addr;
        proxy_set_header X-Forwarded-For $$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $$scheme;
    }
}
EOL

systemctl restart nginx

# Use Certbot to obtain an SSL certificate and configure NGINX for HTTPS.
certbot --nginx --non-interactive --agree-tos --email ${certbot_email} -d ${dns_name}
