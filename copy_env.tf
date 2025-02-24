resource "null_resource" "copy_env" {
  count = length(aws_instance.my_ec2)

  provisioner "file" {
    source      = ".env"
    destination = "/home/ubuntu/.env"

    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa_github")
    }
  }
}
