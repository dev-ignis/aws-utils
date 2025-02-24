output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.my_ec2.id
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.my_ec2.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance. Update the key file path as needed."
  value       = "ssh -i ~/.ssh/id_rsa_github ubuntu@${aws_instance.my_ec2.public_ip}"
}

output "load_balancer_dns" {
  description = "DNS name of the load balancer, if enabled"
  value       = var.enable_load_balancer ? module.alb[0].dns_name : ""
}
