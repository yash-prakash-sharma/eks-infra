output "secret_arn" {
  description = "The ARN of the AWS Secrets Manager Secret"
  value       = aws_secretsmanager_secret.app_secrets.arn
}

output "secret_name" {
  description = "The name of the AWS Secrets Manager Secret"
  value       = aws_secretsmanager_secret.app_secrets.name
}

output "eso_role_arn" {
  description = "The ARN of the IAM Role created for the External Secrets Operator"
  value       = aws_iam_role.eso_role.arn
}
