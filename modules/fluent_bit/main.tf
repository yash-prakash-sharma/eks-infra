# IAM Role for Fluent Bit Operator (IRSA)
data "aws_iam_policy_document" "fluentbit_assume_role" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
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
    effect = "Allow"
    actions = [
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

resource "aws_eks_pod_identity_association" "fluentbit" {
  cluster_name    = var.cluster_name
  namespace       = "observability"
  service_account = "fluent-bit"
  role_arn        = aws_iam_role.fluentbit_role.arn
}
