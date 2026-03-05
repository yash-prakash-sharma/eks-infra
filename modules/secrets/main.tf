# 1. Create the AWS Secrets Manager Secret
resource "aws_secretsmanager_secret" "app_secrets" {
  name        = "${var.name_prefix}-app-secrets"
  description = "Application secrets for the EKS microservices"
  tags        = var.tags
}

# Provide an initial dummy/placeholder version to avoid errors, allowing users to update it later in the console.
resource "aws_secretsmanager_secret_version" "app_secrets_initial" {
  secret_id     = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    MYSQL_USER     = "admin"
    MYSQL_PASSWORD = "CHANGE_ME_IN_AWS_CONSOLE"
    SECRET_KEY     = "CHANGE_ME_IN_AWS_CONSOLE"
  })

  lifecycle {
    ignore_changes = [secret_string] # Ensure Terraform doesn't overwrite it if the user manually updates it in AWS
  }
}

# 2. IAM Role for External Secrets Operator (IRSA)
data "aws_iam_policy_document" "eso_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:external-secrets-sa"] # The namespace and SA name we will use in Kubernetes
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [var.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eso_role" {
  name               = "${var.name_prefix}-eso-role"
  assume_role_policy = data.aws_iam_policy_document.eso_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "eso_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.app_secrets.arn]
  }
}

resource "aws_iam_policy" "eso_policy" {
  name        = "${var.name_prefix}-eso-policy"
  description = "Policy allowing External Secrets Operator to read the app secret"
  policy      = data.aws_iam_policy_document.eso_policy.json
}

resource "aws_iam_role_policy_attachment" "eso_policy_attach" {
  role       = aws_iam_role.eso_role.name
  policy_arn = aws_iam_policy.eso_policy.arn
}
