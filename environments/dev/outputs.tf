output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "ui_bucket_name" {
  description = "S3 bucket name for UI build (CloudFront origin)"
  value       = module.s3_ui.bucket_name
}

output "ui_bucket_arn" {
  description = "S3 bucket ARN for UI"
  value       = module.s3_ui.bucket_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.cloudfront_domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  value       = module.cloudfront.cloudfront_hosted_zone_id
}

output "cloudfront_url" {
  description = "URL for the frontend"
  value       = "https://${module.cloudfront.cloudfront_domain_name}"
}

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}
/*
output "rds_endpoint" {
  description = "RDS instance endpoint (use from bastion)"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS port"
  value       = module.rds.port
}

output "bastion_public_ip" {
  description = "Bastion host public IP for SSH"
  value       = module.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "Example SSH command to bastion"
  value       = "ssh -i <your-key.pem> ec2-user@${module.bastion.public_ip}"
}
*/