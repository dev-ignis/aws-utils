resource "null_resource" "redeploy_front_end" {
  count = var.blue_green_enabled || var.skip_deployment_validation ? 0 : 1

  # Triggers for redeployment
  triggers = {
    frontend_image = var.front_end_image
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "./scripts/redeploy.sh ${var.environment} fe"
    working_dir = path.module
  }

  depends_on = [aws_instance.my_ec2]
}