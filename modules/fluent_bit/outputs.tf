output "fluentbit_role_arn" {
  description = "The ARN of the IAM Role created for Fluent Bit"
  value       = aws_iam_role.fluentbit_role.arn
}
