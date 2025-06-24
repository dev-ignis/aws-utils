resource "null_resource" "redeploy_front_end" {
  count = var.blue_green_enabled || var.skip_deployment_validation ? 0 : length(aws_instance.my_ec2)

  # Sequential deployment using triggers to ensure ordering
  triggers = {
    redeploy = var.front_end_image
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
      "echo 'Starting zero-downtime deployment for frontend on instance ${count.index}'",
      
      "docker pull ${var.front_end_image}",
      
      "TEMP_PORT=$((${var.front_end_port} + 1000))",
      "echo \"Starting new container on temporary port $TEMP_PORT\"",
      
      "docker run -d --env-file /home/ubuntu/.env -e NEXT_RESEND_API_KEY=${var.next_resend_api_key} --name ${var.front_end_container_name}_new -p $TEMP_PORT:${var.front_end_port} ${var.front_end_image}",
      
      "echo 'Waiting for new container to be ready...'",
      "sleep 20",
      
      "for i in {1..12}; do",
      "  if curl -f http://localhost:$TEMP_PORT/ > /dev/null 2>&1; then",
      "    echo 'Health check passed'",
      "    break",
      "  fi",
      "  if [ $i -eq 12 ]; then",
      "    echo 'Health check failed after 60 seconds'",
      "    docker stop ${var.front_end_container_name}_new || true",
      "    docker rm ${var.front_end_container_name}_new || true",
      "    exit 1",
      "  fi",
      "  echo \"Health check attempt $i/12 failed, retrying in 5 seconds...\"",
      "  sleep 5",
      "done",
      
      "echo 'Switching nginx configuration to new container'",
      "sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup || true",
      "sudo sed -i 's/:${var.front_end_port}/'\":$TEMP_PORT\"/g' /etc/nginx/sites-available/default",
      "sudo nginx -t && sudo systemctl reload nginx",
      
      "echo 'Nginx switched to new container, stopping old container'",
      "docker stop ${var.front_end_container_name} || true",
      "docker rm ${var.front_end_container_name} || true",
      
      "echo 'Stopping new container and starting on original port'",
      "docker stop ${var.front_end_container_name}_new",
      "docker run -d --env-file /home/ubuntu/.env -e NEXT_RESEND_API_KEY=${var.next_resend_api_key} --name ${var.front_end_container_name} -p ${var.front_end_port}:${var.front_end_port} ${var.front_end_image}",
      
      "sleep 5",
      "echo 'Restoring nginx configuration to original port'",
      "sudo sed -i 's/'\":$TEMP_PORT\"'/:${var.front_end_port}/g' /etc/nginx/sites-available/default",
      "sudo nginx -t && sudo systemctl reload nginx",
      
      "docker rm ${var.front_end_container_name}_new || true",
      
      "echo 'Zero-downtime frontend deployment completed successfully on instance ${count.index}'"
    ]
  }
}
