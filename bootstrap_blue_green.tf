resource "null_resource" "bootstrap_blue_green" {
  count = var.blue_green_enabled ? 1 : 0

  triggers = {
    bootstrap_required = "once"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Bootstrapping blue-green deployment..."
      
      # Get current ALB listener configuration
      MAIN_TG_ARN="${var.enable_load_balancer ? module.alb[0].main_target_group_arn : ""}"
      BLUE_TG_ARN="${var.enable_load_balancer ? module.alb[0].blue_target_group_arn : ""}"
      HTTPS_LISTENER_ARN="${var.enable_load_balancer ? module.alb[0].https_listener_arn : ""}"
      
      echo "Main TG: $MAIN_TG_ARN"
      echo "Blue TG: $BLUE_TG_ARN"
      echo "HTTPS Listener: $HTTPS_LISTENER_ARN"
      
      # Check if blue target group is already populated
      BLUE_TARGET_COUNT=$(aws elbv2 describe-target-health \
        --target-group-arn "$BLUE_TG_ARN" \
        --region ${var.region} \
        --query 'length(TargetHealthDescriptions)' \
        --output text)
      
      if [ "$BLUE_TARGET_COUNT" -eq "0" ]; then
        echo "Blue target group is empty. Bootstrapping..."
        
        # Register instances to blue target group
        echo "Registering instances to blue target group..."
        for instance_id in ${join(" ", aws_instance.my_ec2[*].id)}; do
          echo "Registering $instance_id to blue target group"
          aws elbv2 register-targets \
            --target-group-arn "$BLUE_TG_ARN" \
            --targets Id=$instance_id,Port=80 \
            --region ${var.region}
        done
        
        # Wait for targets to become healthy in blue target group
        echo "Waiting for targets to become healthy in blue target group..."
        sleep 30
        
        # Check blue target group health
        for i in {1..12}; do
          HEALTHY_COUNT=$(aws elbv2 describe-target-health \
            --target-group-arn "$BLUE_TG_ARN" \
            --region ${var.region} \
            --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`] | length(@)' \
            --output text)
          
          TOTAL_COUNT=${length(aws_instance.my_ec2)}
          echo "Blue target group health check $i/12: $HEALTHY_COUNT/$TOTAL_COUNT healthy"
          
          if [ "$HEALTHY_COUNT" -eq "$TOTAL_COUNT" ]; then
            echo "All targets healthy in blue target group!"
            break
          fi
          
          if [ $i -eq 12 ]; then
            echo "ERROR: Blue target group targets did not become healthy"
            exit 1
          fi
          
          sleep 15
        done
        
        # Update HTTPS listener to point to blue target group
        echo "Updating HTTPS listener to point to blue target group..."
        aws elbv2 modify-listener \
          --listener-arn "$HTTPS_LISTENER_ARN" \
          --default-actions Type=forward,TargetGroupArn="$BLUE_TG_ARN" \
          --region ${var.region}
        
        # Wait a moment for listener update
        sleep 10
        
        # Deregister targets from main target group
        echo "Deregistering targets from main target group..."
        for instance_id in ${join(" ", aws_instance.my_ec2[*].id)}; do
          echo "Deregistering $instance_id from main target group"
          aws elbv2 deregister-targets \
            --target-group-arn "$MAIN_TG_ARN" \
            --targets Id=$instance_id \
            --region ${var.region}
        done
        
        echo "Blue-green bootstrap completed successfully!"
        echo "Traffic is now flowing through blue target group"
        echo "Blue-green deployments are now ready to use"
        
      else
        echo "Blue target group already has $BLUE_TARGET_COUNT targets. Bootstrap not needed."
      fi
    EOT
  }

  depends_on = [
    module.alb
  ]
}