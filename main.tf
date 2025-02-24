provider "aws" {
  region = var.region
}

# Create a new VPC
resource "aws_vpc" "spidey_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.instance_name}-vpc"
  }
}

# Create a public subnet in the new VPC
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.spidey_vpc.id
  cidr_block              = var.subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.instance_name}-subnet"
  }
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.spidey_vpc.id

  tags = {
    Name = "${var.instance_name}-igw"
  }
}

# Create a Route Table and a default route to the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.spidey_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.instance_name}-rt"
  }
}

# Associate the Route Table with our public subnet
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a Security Group in our new VPC that allows SSH, HTTP, and HTTPS
resource "aws_security_group" "instance_sg" {
  name        = "${var.instance_name}-sg"
  description = "Allow inbound SSH, HTTP, and HTTPS"
  vpc_id      = aws_vpc.spidey_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the EC2 instance in our new VPC and public subnet
resource "aws_instance" "my_ec2" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # The user_data installs Docker, NGINX, Certbot,
  # pulls your Docker image, runs the container,
  # configures NGINX as a reverse proxy, and obtains an SSL certificate.
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io nginx certbot python3-certbot-nginx
    usermod -aG docker ubuntu
    systemctl start docker
    systemctl enable docker
    docker pull ${var.docker_image}
    docker stop site_spidey_app || true
    docker rm site_spidey_app || true
    # Run the container exposing port 5000 internally
    docker run -d --name site_spidey_app -p 5000:5000 ${var.docker_image}

    # Configure NGINX to reverse proxy HTTP to the Docker container
    cat > /etc/nginx/sites-available/default << 'EOL'
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name ${var.dns_name};

        location / {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
    EOL

    systemctl restart nginx

    # Use Certbot to obtain an SSL certificate and configure NGINX for HTTPS.
    certbot --nginx --non-interactive --agree-tos --email ${var.certbot_email} -d ${var.dns_name}
  EOF

  tags = {
    Name = var.instance_name
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}
