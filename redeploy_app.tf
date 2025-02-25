resource "null_resource" "redeploy_app" {
  count = length(aws_instance.my_ec2)

  triggers = {
    redeploy = var.go_gin_app_image
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "docker pull ${var.go_gin_app_image}",
      "docker stop ${var.app_container_name} || true",
      "docker rm ${var.app_container_name} || true",
      "docker run -d --env-file /home/ubuntu/.env --name ${var.app_container_name} -p ${var.app_port}:${var.app_port} ${var.go_gin_app_image}"
    ]
  }
}
