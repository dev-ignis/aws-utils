
resource "null_resource" "deployment_validation" {
  count = var.enable_rollback && !var.skip_deployment_validation ? 1 : 0

  triggers = {
    backend_image = var.backend_image
    frontend_image = var.front_end_image
    validation_timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting deployment validation..."
      
      # Get ALB target group ARN based on deployment type
      if [ "${var.blue_green_enabled}" = "true" ]; then
        if [ "${var.active_target_group}" = "blue" ]; then
          TARGET_GROUP_ARN="${var.enable_load_balancer ? module.alb[0].green_target_group_arn : ""}"
          echo "Validating green target group deployment..."
        else
          TARGET_GROUP_ARN="${var.enable_load_balancer ? module.alb[0].blue_target_group_arn : ""}"
          echo "Validating blue target group deployment..."
        fi
      else
        TARGET_GROUP_ARN="${var.enable_load_balancer ? module.alb[0].main_target_group_arn : ""}"
        echo "Validating rolling deployment..."
      fi
      
      # Wait for deployment to stabilize
      echo "Waiting ${var.rollback_timeout_minutes} minutes for deployment to stabilize..."
      sleep $((${var.rollback_timeout_minutes} * 60))
      
      # Check target health if using load balancer
      if [ "${var.enable_load_balancer}" = "true" ] && [ -n "$TARGET_GROUP_ARN" ]; then
        echo "Checking target group health..."
        
        healthy_count=$(aws elbv2 describe-target-health \
          --target-group-arn "$TARGET_GROUP_ARN" \
          --region ${var.region} \
          --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)')
        
        total_count=${length(aws_instance.my_ec2)}
        unhealthy_count=$(aws elbv2 describe-target-health \
          --target-group-arn "$TARGET_GROUP_ARN" \
          --region ${var.region} \
          --query 'TargetHealthDescriptions[?TargetHealth.State==`unhealthy`] | length(@)')
        
        echo "Target health status: $healthy_count healthy, $unhealthy_count unhealthy out of $total_count total"
        
        if [ "$healthy_count" -lt "$total_count" ]; then
          echo "VALIDATION FAILED: Not all targets are healthy"
          echo "Triggering automatic rollback..."
          
          # Trigger rollback based on deployment type
          if [ "${var.blue_green_enabled}" = "true" ]; then
            echo "Blue-green rollback: switching back to previous target group..."
            
            # Switch listener back to previous target group
            if [ "${var.active_target_group}" = "blue" ]; then
              ROLLBACK_TG_ARN="${var.enable_load_balancer ? module.alb[0].blue_target_group_arn : ""}"
              echo "Rolling back to blue target group"
            else
              ROLLBACK_TG_ARN="${var.enable_load_balancer ? module.alb[0].green_target_group_arn : ""}"
              echo "Rolling back to green target group"
            fi
            
            aws elbv2 modify-listener \
              --listener-arn ${var.enable_load_balancer ? module.alb[0].https_listener_arn : ""} \
              --default-actions Type=forward,TargetGroupArn="$ROLLBACK_TG_ARN" \
              --region ${var.region}
            
            echo "Traffic switched back to previous target group"
            
          else
            echo "Rolling deployment rollback: restarting containers with previous image..."
            # This would require storing previous image versions
            echo "Manual intervention required for rolling deployment rollback"
          fi
          
          exit 1
        else
          echo "VALIDATION PASSED: All targets are healthy"
          echo "Deployment validation completed successfully"
        fi
      else
        echo "No load balancer enabled, performing direct instance health checks..."
        
        # Direct health check on instances
        failed_instances=0
        for ip in ${join(" ", aws_instance.my_ec2[*].public_ip)}; do
          if ! curl -f -m 10 "http://$ip/health" > /dev/null 2>&1; then
            echo "Health check failed for instance: $ip"
            failed_instances=$((failed_instances + 1))
          else
            echo "Health check passed for instance: $ip"
          fi
        done
        
        if [ $failed_instances -gt 0 ]; then
          echo "VALIDATION FAILED: $failed_instances instance(s) failed health checks"
          exit 1
        else
          echo "VALIDATION PASSED: All instances passed health checks"
        fi
      fi
      
      echo "Deployment validation completed successfully"
    EOT
  }

  depends_on = [
    null_resource.redeploy_app,
    null_resource.redeploy_front_end,
    null_resource.blue_green_deploy
  ]
}

resource "null_resource" "deployment_monitor" {
  count = var.enable_rollback && !var.skip_deployment_validation ? 1 : 0

  triggers = {
    backend_image = var.backend_image
    frontend_image = var.front_end_image
    monitor_timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Starting deployment monitoring..."
      
      # Monitor for the next 10 minutes after validation
      monitor_duration=600  # 10 minutes
      check_interval=30     # 30 seconds
      checks=$((monitor_duration / check_interval))
      
      for i in $(seq 1 $checks); do
        echo "Monitoring check $i/$checks..."
        
        if [ "${var.enable_load_balancer}" = "true" ]; then
          # Check ALB target health
          if [ "${var.blue_green_enabled}" = "true" ]; then
            if [ "${var.active_target_group}" = "blue" ]; then
              TARGET_GROUP_ARN="${var.enable_load_balancer ? module.alb[0].green_target_group_arn : ""}"
            else
              TARGET_GROUP_ARN="${var.enable_load_balancer ? module.alb[0].blue_target_group_arn : ""}"
            fi
          else
            TARGET_GROUP_ARN="${var.enable_load_balancer ? module.alb[0].main_target_group_arn : ""}"
          fi
          
          unhealthy_count=$(aws elbv2 describe-target-health \
            --target-group-arn "$TARGET_GROUP_ARN" \
            --region ${var.region} \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`unhealthy`] | length(@)')
          
          if [ "$unhealthy_count" -gt 0 ]; then
            echo "WARNING: $unhealthy_count unhealthy targets detected during monitoring"
            echo "Consider manual intervention if issues persist"
          fi
        else
          # Direct instance monitoring
          failed_count=0
          for ip in ${join(" ", aws_instance.my_ec2[*].public_ip)}; do
            if ! curl -f -m 10 "http://$ip/health" > /dev/null 2>&1; then
              failed_count=$((failed_count + 1))
            fi
          done
          
          if [ $failed_count -gt 0 ]; then
            echo "WARNING: $failed_count instance(s) failing health checks during monitoring"
          fi
        fi
        
        sleep $check_interval
      done
      
      echo "Deployment monitoring completed"
    EOT
  }

  depends_on = [null_resource.deployment_validation]
}

output "deployment_status" {
  description = "Deployment status information"
  value = {
    rollback_enabled = var.enable_rollback
    blue_green_enabled = var.blue_green_enabled
    active_target_group = var.blue_green_enabled ? var.active_target_group : "rolling"
    load_balancer_enabled = var.enable_load_balancer
  }
}