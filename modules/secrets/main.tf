# 1. Create the AWS Secrets Manager Secret
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.name_prefix}-app-secrets"
  description             = "Application secrets for the EKS microservices"
  tags                    = var.tags
  recovery_window_in_days = 7
}

# Provide an initial dummy/placeholder version to avoid errors, allowing users to update it later in the console.
resource "aws_secretsmanager_secret_version" "app_secrets_initial" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    MYSQL_USER     = "admin"
    MYSQL_PASSWORD = "CHANGE_ME_IN_AWS_CONSOLE"
    SECRET_KEY     = "CHANGE_ME_IN_AWS_CONSOLE"
  })

  lifecycle {
    ignore_changes = [secret_string] # Ensure Terraform doesn't overwrite it if the user manually updates it in AWS
  }
}
