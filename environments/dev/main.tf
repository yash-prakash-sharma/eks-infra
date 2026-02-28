locals {
  tags = {
    Environment = "dev"
    Project     = "eks-app"
    ManagedBy   = "terraform"
  }
}

# ------------------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  name_prefix = var.name_prefix
  cidr_block  = "10.0.0.0/16"
  tags        = local.tags
}

# ------------------------------------------------------------------------------
# S3 bucket for UI build (CloudFront origin)
# ------------------------------------------------------------------------------
module "s3_ui" {
  source = "../../modules/s3"

  bucket_name       = "${var.name_prefix}-dev-ui"
  enable_versioning = false
  tags              = local.tags
}

# ------------------------------------------------------------------------------
# ECR private repositories
# ------------------------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"

  repository_names = var.ecr_repo_names
  tags             = local.tags
}

# ------------------------------------------------------------------------------
# RDS MySQL (private subnets, accessible via bastion)
# ------------------------------------------------------------------------------
module "rds" {
  source = "../../modules/rds"

  name_prefix                 = var.name_prefix
  vpc_id                      = module.vpc.vpc_id
  subnet_ids                  = module.vpc.private_subnet_ids
  allowed_security_group_ids  = [module.bastion.security_group_id]

  db_name         = var.db_name
  username        = var.db_username
  password        = var.db_password
  instance_class  = var.db_instance_class
  tags            = local.tags
}

# ------------------------------------------------------------------------------
# Bastion host (public subnet, can connect to RDS)
# ------------------------------------------------------------------------------
module "bastion" {
  source = "../../modules/bastion"

  name_prefix        = var.name_prefix
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.public_subnet_ids[0]
  allowed_ssh_cidrs  = [var.bastion_ssh_cidr]
  key_name           = var.bastion_key_name
  tags               = local.tags
}

# ------------------------------------------------------------------------------
# CloudFront (origin: dev-ui S3 bucket)
# ------------------------------------------------------------------------------
module "cloudfront" {
  source = "../../modules/cloudfront"

  name_prefix                          = var.name_prefix
  origin_bucket_name                    = module.s3_ui.bucket_name
  origin_bucket_regional_domain_name    = module.s3_ui.bucket_regional_domain_name
  default_root_object                   = "index.html"
  attach_bucket_policy                  = true
  spa_fallback                          = true
  tags                                 = local.tags
}