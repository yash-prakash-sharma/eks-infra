output "autoscaler_role_arn" {
  description = "The ARN of the IAM Role created for the Cluster Autoscaler"
  value       = aws_iam_role.cluster_autoscaler_role.arn
}
