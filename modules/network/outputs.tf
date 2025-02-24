output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "instance_subnet_id" {
  description = "The ID of the subnet for instance placement (first subnet)"
  value       = aws_subnet.subnet1.id
}

output "lb_subnet_ids" {
  description = "List of subnet IDs for the load balancer"
  value       = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
}

output "security_group_id" {
  description = "The ID of the security group"
  value       = aws_security_group.instance_sg.id
}
