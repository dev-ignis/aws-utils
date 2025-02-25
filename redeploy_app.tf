resource "null_resource" "ansible_deploy" {
  # We use a trigger so that a change in the image (or any variable) causes a re-run.
  triggers = {
    redeploy = var.go_gin_app_image
  }

  provisioner "local-exec" {
    # Create a comma-separated inventory string of all instance public IPs.
    command = <<EOT
      ansible-playbook -i '${join(",", aws_instance.my_ec2[*].public_ip)},' deploy.yml \
        --private-key ${var.ssh_private_key_path} \
        --user ubuntu
EOT
  }
}
