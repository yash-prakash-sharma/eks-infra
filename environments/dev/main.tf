locals {
  tags = {
    Environment = "dev"
    Project     = "eks-app"
    ManagedBy   = "terraform"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
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

  name_prefix = var.name_prefix
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  allowed_security_group_ids = [
    module.bastion.security_group_id,
    module.eks.cluster_security_group_id
  ]

  db_name        = var.db_name
  username       = var.db_username
  password       = var.db_password
  instance_class = var.db_instance_class
  tags           = local.tags
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
  desired_size        = 1
  min_size            = 1
  max_size            = 4
  node_instance_types = ["t3.large"]

  tags = local.tags
}

# ------------------------------------------------------------------------------
# Bastion host (public subnet, can connect to RDS)
# ------------------------------------------------------------------------------
module "bastion" {
  source = "../../modules/bastion"

  name_prefix       = var.name_prefix
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  allowed_ssh_cidrs = [var.bastion_ssh_cidr]
  key_name          = var.bastion_key_name
  tags              = local.tags
}

# ------------------------------------------------------------------------------
# CloudFront (origin: dev-ui S3 bucket)
# ------------------------------------------------------------------------------
module "cloudfront" {
  source = "../../modules/cloudfront"

  name_prefix                        = var.name_prefix
  origin_bucket_name                 = module.s3_ui.bucket_name
  origin_bucket_regional_domain_name = module.s3_ui.bucket_regional_domain_name
  default_root_object                = "index.html"
  attach_bucket_policy               = true
  spa_fallback                       = true
  tags                               = local.tags
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
# Secrets Manager (Secret Provisioning Only)
# ------------------------------------------------------------------------------
module "secrets" {
  source = "../../modules/secrets"

  name_prefix = var.name_prefix

  depends_on = [module.eks]

  tags = local.tags
}

# ------------------------------------------------------------------------------
# Observability: Fluent Bit (Logs)
# ------------------------------------------------------------------------------
module "fluent_bit" {
  source = "../../modules/fluent_bit"

  name_prefix  = var.name_prefix
  cluster_name = module.eks.cluster_name

  depends_on = [module.eks]

  tags = local.tags
}