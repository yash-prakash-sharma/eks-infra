terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform-user"
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "eks-app"
      ManagedBy   = "terraform"
    }
  }
}
