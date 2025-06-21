provider "aws" {
  region = var.region
}

module "network" {
  source             = "./modules/network"
  instance_name      = var.instance_name
  vpc_cidr           = var.vpc_cidr
  subnet_cidrs       = var.subnet_cidrs
  availability_zones = var.availability_zones
  backend_port       = var.backend_port
}

module "dynamodb" {
  source        = "./modules/dynamodb"
  table_name    = "${var.instance_name}-table"
  billing_mode  = "PAY_PER_REQUEST"
  hash_key      = "Id"
  hash_key_type = "S"
  tags = {
    Environment = var.environment
    Name        = "${var.instance_name}-dynamodb"
  }
}

# Create EC2 instances distributed across subnets
resource "aws_instance" "my_ec2" {
  count                  = var.instance_count
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = module.network.lb_subnet_ids[count.index % length(module.network.lb_subnet_ids)]
  vpc_security_group_ids = [module.network.instance_security_group_id]

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    backend_image            = var.backend_image
    front_end_image          = var.front_end_image
    backend_container_name   = var.backend_container_name
    front_end_container_name = var.front_end_container_name
    backend_port             = var.backend_port
    front_end_port           = var.front_end_port
    dns_name                 = var.dns_name
    certbot_email            = var.certbot_email
  })

  tags = {
    Name = "${var.instance_name}-${count.index}"
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Pass required values to the ALB module, including the staging DNS name.
module "s3_storage" {
  source = "./modules/s3"
  
  instance_name      = var.instance_name
  bucket_name_suffix = var.s3_bucket_name_suffix
  use_case          = var.s3_use_case
  
  tags = {
    Environment = var.environment
    Project     = "Amygdalas"
    Purpose     = var.s3_use_case
    Owner       = var.instance_name
  }
  
  # Data Organization
  primary_data_prefix      = var.s3_primary_data_prefix
  secondary_data_prefixes  = var.s3_secondary_data_prefixes
  
  # Intelligent Tiering Configuration
  enable_intelligent_tiering = var.enable_s3_intelligent_tiering
  
  # Lifecycle Policy Configuration
  enable_lifecycle_policy = var.enable_s3_lifecycle_policy
  lifecycle_transitions   = var.s3_lifecycle_transitions
  
  # Security Configuration
  versioning_enabled = var.s3_versioning_enabled
  kms_key_id        = var.s3_kms_key_id
  trusted_accounts  = var.s3_trusted_accounts
  
  # IAM Configuration
  create_read_only_role = var.create_s3_read_only_role
  create_admin_role     = var.create_s3_admin_role
  
  # Temporary Data Configuration
  temp_prefixes = var.s3_temp_prefixes
  
  # Partition Configuration
  setup_athena_partitions = var.setup_s3_athena_partitions
  
  # Logging Configuration
  enable_access_logging = var.enable_s3_access_logging
  log_retention_days   = var.s3_log_retention_days
}

module "alb" {
  source               = "./modules/alb"
  count                = var.enable_load_balancer ? 1 : 0
  instance_name        = var.instance_name
  app_port             = var.backend_port
  vpc_id               = module.network.vpc_id
  lb_subnet_ids        = module.network.lb_subnet_ids
  security_group_id    = module.network.alb_security_group_id
  instance_ids         = aws_instance.my_ec2[*].id
  staging_api_dns_name = var.staging_api_dns_name
  domain_name          = var.hosted_zone_name
  environment          = var.environment
  route53_zone_id      = var.route53_zone_id
  skip_route53          = var.skip_route53
}
