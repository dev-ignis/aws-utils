# Force re-run user-data setup on existing instances
resource "null_resource" "force_setup" {
  count = length(aws_instance.my_ec2)

  triggers = {
    instance_id = aws_instance.my_ec2[count.index].id
    force_run = timestamp()  # This will trigger every time
  }

  connection {
    type        = "ssh"
    host        = aws_instance.my_ec2[count.index].public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    timeout     = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Starting forced setup on instance ${count.index}'",
      "sudo apt-get update -y",
      "sudo apt-get install -y docker.io nginx git curl nodejs npm",
      "sudo npm install -g yarn",
      "sudo usermod -aG docker ubuntu",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo docker pull ${var.backend_image}",
      "sudo docker stop ${var.backend_container_name} || true",
      "sudo docker rm ${var.backend_container_name} || true",
      "sudo docker run -d --name ${var.backend_container_name} -p ${var.backend_port}:${var.backend_port} -e AWS_REGION=${var.region} -e CLOUDWATCH_LOG_GROUP=mht-logs-staging -e CLOUDWATCH_LOG_STREAM=mht-app-stream-staging -e CLOUDWATCH_APP_LOG_STREAM=mht-app-stream-all-staging -e CLOUDWATCH_HEALTH_LOG_STREAM=mht-app-stream-health-staging -e SWAGGER_HOST=staging.api.amygdalas.com ${var.backend_image}",
      "sudo docker pull ${var.front_end_image}",
      "sudo docker stop ${var.front_end_container_name} || true", 
      "sudo docker rm ${var.front_end_container_name} || true",
      "sudo docker run -d --name ${var.front_end_container_name} -p ${var.front_end_port}:${var.front_end_port} ${var.front_end_image}",
      "sleep 10"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        sudo tee /etc/nginx/sites-available/default > /dev/null << 'EOF'
# API subdomain server block - all traffic goes directly to backend
server {
    listen 80;
    listen [::]:80;
    server_name api.amygdalas.com staging.api.amygdalas.com;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:${var.backend_port}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # All other traffic goes to backend, without the /api/ prefix
    location / {
        proxy_pass http://127.0.0.1:${var.backend_port};
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
        proxy_pass http://127.0.0.1:${var.backend_port}/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API endpoints still accessible through path-based routing
    location /api/ {
        proxy_pass http://127.0.0.1:${var.backend_port}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Frontend
    location / {
        proxy_pass http://127.0.0.1:${var.front_end_port};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
      EOT
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "sudo nginx -t",
      "sudo systemctl restart nginx",
      "sudo docker ps",
      "echo 'Setup complete on instance ${count.index}'"
    ]
  }
}