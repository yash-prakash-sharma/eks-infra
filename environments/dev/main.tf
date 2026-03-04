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
# S3 bucket for file-service uploads
# ------------------------------------------------------------------------------
module "s3_files" {
  source = "../../modules/s3"

  bucket_name       = "${var.name_prefix}-files"
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
  allowed_security_group_ids  = [
    module.bastion.security_group_id,
    module.eks.cluster_security_group_id
  ]

  db_name         = var.db_name
  username        = var.db_username
  password        = var.db_password
  instance_class  = var.db_instance_class
  tags            = local.tags
}

# ------------------------------------------------------------------------------
# EKS Cluster & Node Group
# ------------------------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  name_prefix = var.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  
  bastion_security_group_id = module.bastion.security_group_id
  s3_bucket_arn             = module.s3_files.bucket_arn

  # Optional Overrides
  desired_size         = 1
  min_size             = 1
  max_size             = 4
  node_instance_types  = ["t3.medium"]

  tags = local.tags
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

# ------------------------------------------------------------------------------
# DNS (Route 53 Hosted Zone & ACM SSL Certificate)
# ------------------------------------------------------------------------------
module "dns" {
  source = "../../modules/dns"

  domain_name = var.domain_name
  tags        = local.tags
}

# ------------------------------------------------------------------------------
# AWS Load Balancer Controller
# ------------------------------------------------------------------------------
module "alb_controller" {
  source = "../../modules/alb_controller"

  name_prefix       = var.name_prefix
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]

  tags = local.tags
}

output "alb_controller_role_arn" {
  description = "The ARN of the IAM Role for the AWS Load Balancer Controller (Pass this to Helm)"
  value       = module.alb_controller.alb_controller_role_arn
}

# ------------------------------------------------------------------------------
# Secrets Manager & External Secrets Operator
# ------------------------------------------------------------------------------
module "secrets" {
  source = "../../modules/secrets"

  name_prefix       = var.name_prefix
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]

  tags = local.tags
}