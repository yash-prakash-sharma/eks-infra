output "secret_arn" {
  description = "The ARN of the AWS Secrets Manager Secret"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "secret_name" {
  description = "The name of the AWS Secrets Manager Secret"
  value       = aws_secretsmanager_secret.app_secrets.name
}
