resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name        = "${var.instance_name}-vpc"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name        = "${var.instance_name}-igw"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.subnet_cidrs[0]
  availability_zone = var.availability_zones[0]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.instance_name}-subnet-1"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.subnet_cidrs[1]
  availability_zone = var.availability_zones[1]
  map_public_ip_on_launch = true
  tags = {
    Name        = "${var.instance_name}-subnet-2"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name        = "${var.instance_name}-rt"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}

resource "aws_route_table_association" "subnet1_assoc" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.this.id
}

resource "aws_route_table_association" "subnet2_assoc" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.this.id
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.instance_name}-alb-sg-"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.instance_name}-alb-sg"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}

# EC2 Instance Security Group
resource "aws_security_group" "instance_sg" {
  name_prefix = "${var.instance_name}-instance-sg-"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
    replace_triggered_by  = [aws_security_group.alb_sg]
  }

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow traffic on the app port from ALB
  ingress {
    description     = "Backend port from ALB"
    from_port       = tonumber(var.backend_port)
    to_port         = tonumber(var.backend_port)
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.instance_name}-sg"
    Environment = var.environment
    Module      = "network"
    Owner       = var.instance_name
  }
}
