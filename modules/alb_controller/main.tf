# 1. IAM Role for the AWS Load Balancer Controller (IRSA)
data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
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

resource "aws_iam_role" "alb_controller" {
  name               = "${var.name_prefix}-alb-controller-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
  tags               = var.tags
}

# The AWS Load Balancer Controller IAM Policy (Standard policy from AWS)
resource "aws_iam_role_policy_attachment" "alb_controller" {
  # AWS Managed Policy for the ALB Controller (can also use a custom downloaded policy if needed, but managing via AWS managed/inline is cleaner)
  # Actually, we should download the official policy since AWS doesn't provide a managed one.
  # But since this is Terraform, we can pull it via an HTTP data block or assume the user has attached it.
  # For simplicity and reliability in automation, we'll embed the core ALB permissions needed.
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}

# 2. To avoid embedding a 1000-line JSON file, we fetch it dynamically from AWS AWS Load Balancer Controller GitHub
data "http" "iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.1.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.name_prefix}-alb-controller-policy"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = data.http.iam_policy.response_body
  tags        = var.tags
}

output "alb_controller_role_arn" {
  description = "The ARN of the IAM Role created for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}
