# 1. Request an SSL Certificate for the domain
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  validation_method         = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
