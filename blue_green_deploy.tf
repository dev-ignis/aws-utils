
locals {
  active_tg_arn = var.active_target_group == "blue" ? (var.enable_load_balancer ? module.alb[0].blue_target_group_arn : null) : (var.enable_load_balancer ? module.alb[0].green_target_group_arn : null)
  inactive_tg_arn = var.active_target_group == "blue" ? (var.enable_load_balancer ? module.alb[0].green_target_group_arn : null) : (var.enable_load_balancer ? module.alb[0].blue_target_group_arn : null)
  inactive_color = var.active_target_group == "blue" ? "green" : "blue"
}

resource "null_resource" "blue_green_deploy" {
  count = var.blue_green_enabled && var.enable_load_balancer ? 1 : 0

  triggers = {
    backend_image = var.backend_image
    frontend_image = var.front_end_image
    deployment_timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting blue-green deployment..."
      echo "Active target group: ${var.active_target_group}"
      echo "Deploying to inactive target group: ${local.inactive_color}"
      
      # Deploy to inactive target group instances
      echo "Deploying application to ${local.inactive_color} target group instances..."
      
      # Attach instances to inactive target group
      echo "Attaching instances to ${local.inactive_color} target group..."
      for instance_id in ${join(" ", aws_instance.my_ec2[*].id)}; do
        aws elbv2 register-targets \
          --target-group-arn ${local.inactive_tg_arn} \
          --targets Id=$instance_id,Port=80 \
          --region ${var.region}
      done
      
      # Wait for health checks to pass
      echo "Waiting for health checks to pass on ${local.inactive_color} target group..."
      sleep 60
      
      # Check if all targets are registered (healthy or initial state)
      # Note: Targets show as "unused" until attached to a listener, so we check for registration
      registered_count=$(aws elbv2 describe-target-health \
        --target-group-arn ${local.inactive_tg_arn} \
        --region ${var.region} \
        --query 'length(TargetHealthDescriptions)')
      
      total_count=${length(aws_instance.my_ec2)}
      
      if [ "$registered_count" -eq "$total_count" ]; then
        echo "All targets registered in ${local.inactive_color} target group. Switching traffic..."
        
        # Update HTTPS listener to point to inactive target group
        aws elbv2 modify-listener \
          --listener-arn ${var.enable_load_balancer ? module.alb[0].https_listener_arn : ""} \
          --default-actions Type=forward,TargetGroupArn=${local.inactive_tg_arn} \
          --region ${var.region}
        
        echo "Traffic switched to ${local.inactive_color} target group successfully!"
        
        # Deregister targets from old active target group
        echo "Deregistering targets from old active target group..."
        for instance_id in ${join(" ", aws_instance.my_ec2[*].id)}; do
          aws elbv2 deregister-targets \
            --target-group-arn ${local.active_tg_arn} \
            --targets Id=$instance_id \
            --region ${var.region}
        done
        
        echo "Blue-green deployment completed successfully!"
        echo "New active target group: ${local.inactive_color}"
        echo "Remember to update the active_target_group variable to '${local.inactive_color}' for the next deployment"
        
      else
        echo "Registration failed. Only $registered_count out of $total_count targets are registered."
        echo "Rolling back - deregistering targets from ${local.inactive_color} target group..."
        
        for instance_id in ${join(" ", aws_instance.my_ec2[*].id)}; do
          aws elbv2 deregister-targets \
            --target-group-arn ${local.inactive_tg_arn} \
            --targets Id=$instance_id \
            --region ${var.region}
        done
        
        echo "Rollback completed. Traffic remains on ${var.active_target_group} target group."
        exit 1
      fi
    EOT
  }

  depends_on = [
    null_resource.redeploy_app,
    null_resource.redeploy_front_end,
    null_resource.bootstrap_blue_green,
    null_resource.blue_green_app_deploy,
    null_resource.blue_green_frontend_deploy
  ]
}

resource "null_resource" "blue_green_app_deploy" {
  count = var.blue_green_enabled ? length(aws_instance.my_ec2) : 0

  triggers = {
    backend_image = var.backend_image
    instance_id = aws_instance.my_ec2[count.index].id
    deployment_timestamp = timestamp()
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "echo 'Blue-green deployment: updating backend application on instance ${count.index}'",
      
      "docker pull ${var.backend_image}",
      
      "docker stop ${var.backend_container_name} || true",
      "docker rm ${var.backend_container_name} || true",
      
      "docker run -d --env-file /home/ubuntu/.env --name ${var.backend_container_name} -p ${var.backend_port}:${var.backend_port} -v /home/ubuntu/AuthKey_FTPK448DLL.p8:/app/AuthKey_FTPK448DLL.p8:ro ${var.backend_image}",
      
      "echo 'Waiting for application to start...'",
      "sleep 15",
      
      "for i in {1..12}; do",
      "  if curl -f http://localhost:${var.backend_port}/health > /dev/null 2>&1; then",
      "    echo 'Backend health check passed on instance ${count.index}'",
      "    break",
      "  fi",
      "  if [ $i -eq 12 ]; then",
      "    echo 'Backend health check failed on instance ${count.index}'",
      "    exit 1",
      "  fi",
      "  echo \"Health check attempt $i/12 failed, retrying in 5 seconds...\"",
      "  sleep 5",
      "done",
      
      "echo 'Backend deployment completed successfully on instance ${count.index}'"
    ]
  }
}

resource "null_resource" "blue_green_frontend_deploy" {
  count = var.blue_green_enabled && var.front_end_image != "" ? length(aws_instance.my_ec2) : 0

  triggers = {
    frontend_image = var.front_end_image
    instance_id = aws_instance.my_ec2[count.index].id
    deployment_timestamp = timestamp()
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "echo 'Blue-green deployment: updating frontend application on instance ${count.index}'",
      
      "docker pull ${var.front_end_image}",
      
      "docker stop ${var.front_end_container_name} || true",
      "docker rm ${var.front_end_container_name} || true",
      
      "docker run -d --env-file /home/ubuntu/.env -e NEXT_RESEND_API_KEY=${var.next_resend_api_key} --name ${var.front_end_container_name} -p ${var.front_end_port}:${var.front_end_port} ${var.front_end_image}",
      
      "echo 'Waiting for frontend to start...'",
      "sleep 20",
      
      "for i in {1..12}; do",
      "  if curl -f http://localhost:${var.front_end_port}/ > /dev/null 2>&1; then",
      "    echo 'Frontend health check passed on instance ${count.index}'",
      "    break",
      "  fi",
      "  if [ $i -eq 12 ]; then",
      "    echo 'Frontend health check failed on instance ${count.index}'",
      "    exit 1",
      "  fi",
      "  echo \"Health check attempt $i/12 failed, retrying in 5 seconds...\"",
      "  sleep 5",
      "done",
      
      "echo 'Frontend deployment completed successfully on instance ${count.index}'"
    ]
  }

  depends_on = [null_resource.blue_green_app_deploy]
}