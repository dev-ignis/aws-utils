resource "null_resource" "copy_cert" {
  count = length(aws_instance.my_ec2)

  provisioner "file" {
    source      = "AuthKey_FTPK448DLL.p8"
    destination = "/home/ubuntu/AuthKey_FTPK448DLL.p8"

    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
  }
}
