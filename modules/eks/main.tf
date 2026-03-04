# ------------------------------------------------------------------------------
# EKS Cluster IAM Role
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ------------------------------------------------------------------------------
# EKS Cluster
# ------------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = "${var.name_prefix}-eks-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids = var.subnet_ids
    # Enforce private cluster API endpoint
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  access_config {
      authentication_mode = "API_AND_CONFIG_MAP"
      bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]

  tags = var.tags
}

# ------------------------------------------------------------------------------
# IAM OIDC Provider for IAM Roles for Service Accounts (IRSA)
# ------------------------------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = var.tags
}

# Allow Bastion host to communicate with the EKS API server
resource "aws_security_group_rule" "bastion_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.bastion_security_group_id
  description              = "Allow Bastion host to access EKS API server"
}

# ------------------------------------------------------------------------------
# EKS Node Group IAM Role
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# Custom policy to allow nodes to access the S3 bucket
data "aws_iam_policy_document" "s3_access" {
  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_access" {
  name        = "${var.name_prefix}-eks-s3-access"
  description = "Allows EKS nodes to access the file-service S3 bucket"
  policy      = data.aws_iam_policy_document.s3_access.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "node_s3_access" {
  policy_arn = aws_iam_policy.s3_access.arn
  role       = aws_iam_role.node.name
}

# ------------------------------------------------------------------------------
# EKS Node Group
# ------------------------------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  version         = var.cluster_version

  instance_types = var.node_instance_types

  # Use a custom launch template to configure IMDSv2 hop limit for the ALB Controller
  launch_template {
    name    = aws_launch_template.node.name
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = var.tags
}

# Custom Launch Template to ensure pods can hit IMDSv2 (requires hop limit 2)
resource "aws_launch_template" "node" {
  name_prefix   = "${var.name_prefix}-node-template"
  update_default_version = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = var.tags
}
