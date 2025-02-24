output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.this.id
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.instance_sg.id
}
