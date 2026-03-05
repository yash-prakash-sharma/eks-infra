# IAM Role for Fluent Bit Operator (IRSA)
data "aws_iam_policy_document" "fluentbit_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:observability:fluent-bit"]
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

resource "aws_iam_role" "fluentbit_role" {
  name               = "${var.name_prefix}-fluentbit-role"
  assume_role_policy = data.aws_iam_policy_document.fluentbit_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "fluentbit_policy" {
  statement {
    effect    = "Allow"
    actions   = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy" "fluentbit_policy" {
  name        = "${var.name_prefix}-fluentbit-policy"
  description = "Policy allowing Fluent Bit to push logs to CloudWatch"
  policy      = data.aws_iam_policy_document.fluentbit_policy.json
}

resource "aws_iam_role_policy_attachment" "fluentbit_policy_attach" {
  role       = aws_iam_role.fluentbit_role.name
  policy_arn = aws_iam_policy.fluentbit_policy.arn
}
