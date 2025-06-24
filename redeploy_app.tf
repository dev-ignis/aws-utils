resource "null_resource" "redeploy_app" {
  count = var.blue_green_enabled || var.skip_deployment_validation ? 0 : 1

  # Triggers for redeployment
  triggers = {
    backend_image = var.backend_image
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "./scripts/redeploy.sh ${var.environment} be"
    working_dir = path.module
  }

  depends_on = [aws_instance.my_ec2]
}