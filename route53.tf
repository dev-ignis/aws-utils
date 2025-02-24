# Create a Route53 DNS record for the EC2 instance only if dns_name is provided
resource "aws_route53_record" "ec2_dns" {
  count   = var.dns_name != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.dns_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.my_ec2.public_ip]
}
