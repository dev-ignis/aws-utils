resource "null_resource" "redeploy_app" {
  count = length(aws_instance.my_ec2)

  triggers = {
    redeploy = var.backend_image
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "docker pull ${var.backend_image}",
      "docker stop ${var.backend_container_name} || true",
      "docker rm ${var.backend_container_name} || true",
      "docker run -d --env-file /home/ubuntu/.env --name ${var.backend_container_name} -p ${var.backend_port}:${var.backend_port} -v /home/ubuntu/AuthKey_FTPK448DLL.p8:/app/AuthKey_FTPK448DLL.p8:ro ${var.backend_image}"
    ]
  }
}
