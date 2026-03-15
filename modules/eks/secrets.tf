
data "aws_caller_identity" "current" {}

locals {
  app_secret_arn = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}-app-secrets-*"
}

resource "aws_iam_role" "secrets_csi" {
  name = "${aws_eks_cluster.main.name}-secrets-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "secrets_csi" {
  name        = "${aws_eks_cluster.main.name}-secrets-csi-policy"
  description = "Allows the Secrets Store CSI Driver to read the application secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [local.app_secret_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_csi" {
  policy_arn = aws_iam_policy.secrets_csi.arn
  role       = aws_iam_role.secrets_csi.name
}

resource "aws_eks_pod_identity_association" "secrets_csi" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "app"
  service_account = "app-sa"
  role_arn        = aws_iam_role.secrets_csi.arn

  depends_on = [
    aws_eks_addon.pod_identity
  ]
}

resource "helm_release" "secrets_csi_driver" {
  name = "secrets-store-csi-driver"

  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.3"

  # MUST be set if you use ENV variables synced from the CSI driver
  set {
    name  = "syncSecret.enabled"
    value = true
  }

  depends_on = [aws_eks_node_group.main]
}

resource "helm_release" "secrets_csi_driver_aws_provider" {
  name = "secrets-store-csi-driver-provider-aws"

  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.8"

  depends_on = [helm_release.secrets_csi_driver]
}
