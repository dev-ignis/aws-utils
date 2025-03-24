resource "null_resource" "update_nginx" {
  count = length(aws_instance.my_ec2)

  # The trigger will force a re-run whenever the rendered configuration changes.
  triggers = {
    nginx_config_hash = sha256(
      templatefile("${path.module}/nginx.conf.tpl", {
        server_name    = var.dns_name != "" ? var.dns_name : "REPLACE_WITH_METADATA"
        backend_port   = var.backend_port
        front_end_port = var.front_end_image != "" ? var.front_end_port : var.backend_port
      })
    )
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = aws_instance.my_ec2[count.index].public_ip
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
    }
    inline = [
      <<-EOF
        cat > /etc/nginx/sites-available/default << 'EOL'
        ${templatefile("${path.module}/nginx.conf.tpl", {
          server_name    = var.dns_name != "" ? var.dns_name : "$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)",
          backend_port   = var.backend_port,
          front_end_port = var.front_end_image != "" ? var.front_end_port : var.backend_port
        })}
        EOL
      EOF
    ,
      "systemctl restart nginx"
    ]
  }
}
