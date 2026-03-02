output "acm_certificate_arn" {
  description = "The ARN of the ACM Certificate"
  value       = aws_acm_certificate.main.arn
}

output "domain_validation_options" {
  description = "DNS records to add to Hostinger to validate the certificate"
  value       = aws_acm_certificate.main.domain_validation_options
}
