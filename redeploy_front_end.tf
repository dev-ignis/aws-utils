resource "null_resource" "redeploy_front_end" {
  count = length(aws_instance.my_ec2)

  triggers = {
    redeploy = var.front_end_image
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      "docker pull ${var.front_end_image}",
      "docker stop ${var.front_end_container_name} || true",
      "docker rm ${var.front_end_container_name} || true",
      "docker run -d --env-file /home/ubuntu/.env -e NEXT_RESEND_API_KEY=${var.next_resend_api_key} --name ${var.front_end_container_name} -p ${var.front_end_port}:${var.front_end_port} ${var.front_end_image}"
    ]
  }
}
