variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# Resource naming: <name_prefix> e.g. myapp-ue1-dev-eks-app
variable "name_prefix" {
  description = "Prefix for resource names (e.g. myapp-ue1-dev-eks-app)"
  type        = string
}

# Bastion
variable "bastion_ssh_cidr" {
  description = "CIDR allowed to SSH to bastion (e.g. your IP or VPN)"
  type        = string
}

variable "bastion_key_name" {
  description = "EC2 key pair name for bastion SSH"
  type        = string
}

# RDS
variable "db_name" {
  description = "Database name"
  type        = string
  default     = "app"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "ecr_repo_names" {
  description = "ECR private repository names"
  type        = list(string)
  default     = ["login-service", "file-service"]
}

variable "domain_name" {
  description = "Custom domain name (e.g. hostinger domain)"
  type        = string
}
