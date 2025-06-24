resource "null_resource" "redeploy_app" {
  count = var.blue_green_enabled || var.skip_deployment_validation ? 0 : length(aws_instance.my_ec2)

  # Sequential deployment using triggers to ensure ordering
  triggers = {
    redeploy = var.backend_image
    instance_id = aws_instance.my_ec2[count.index].id
    sequence = count.index
    previous_instance = count.index > 0 ? aws_instance.my_ec2[count.index - 1].id : "first"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "echo 'Starting zero-downtime deployment for backend on instance ${count.index}'",
      
      "docker pull ${var.backend_image}",
      
      "TEMP_PORT=$((${var.backend_port} + 1000))",
      "echo \"Starting new container on temporary port $TEMP_PORT\"",
      
      "docker run -d --env-file /home/ubuntu/.env --name ${var.backend_container_name}_new -p $TEMP_PORT:${var.backend_port} -v /home/ubuntu/AuthKey_FTPK448DLL.p8:/app/AuthKey_FTPK448DLL.p8:ro ${var.backend_image}",
      
      "echo 'Waiting for new container to be ready...'",
      "sleep 15",
      
      "for i in {1..12}; do",
      "  if curl -f http://localhost:$TEMP_PORT/health > /dev/null 2>&1; then",
      "    echo 'Health check passed'",
      "    break",
      "  fi",
      "  if [ $i -eq 12 ]; then",
      "    echo 'Health check failed after 60 seconds'",
      "    docker stop ${var.backend_container_name}_new || true",
      "    docker rm ${var.backend_container_name}_new || true",
      "    exit 1",
      "  fi",
      "  echo \"Health check attempt $i/12 failed, retrying in 5 seconds...\"",
      "  sleep 5",
      "done",
      
      "echo 'Switching nginx configuration to new container'",
      "sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup",
      "sudo sed -i 's/:${var.backend_port}/'\":$TEMP_PORT\"/g' /etc/nginx/sites-available/default",
      "sudo nginx -t && sudo systemctl reload nginx",
      
      "echo 'Nginx switched to new container, stopping old container'",
      "docker stop ${var.backend_container_name} || true",
      "docker rm ${var.backend_container_name} || true",
      
      "echo 'Stopping new container and starting on original port'",
      "docker stop ${var.backend_container_name}_new",
      "docker run -d --env-file /home/ubuntu/.env --name ${var.backend_container_name} -p ${var.backend_port}:${var.backend_port} -v /home/ubuntu/AuthKey_FTPK448DLL.p8:/app/AuthKey_FTPK448DLL.p8:ro ${var.backend_image}",
      
      "sleep 5",
      "echo 'Restoring nginx configuration to original port'",
      "sudo sed -i 's/'\":$TEMP_PORT\"'/:${var.backend_port}/g' /etc/nginx/sites-available/default",
      "sudo nginx -t && sudo systemctl reload nginx",
      
      "docker rm ${var.backend_container_name}_new || true",
      
      "echo 'Zero-downtime backend deployment completed successfully on instance ${count.index}'"
    ]
  }
}
