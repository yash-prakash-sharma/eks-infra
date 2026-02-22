resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name_prefix}-s3-oac"
  description                       = "OAC for S3 origin ${var.origin_bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled      = true
  default_root_object = var.default_root_object
  comment             = var.comment
  price_class         = var.price_class

  origin {
    domain_name              = var.origin_bucket_regional_domain_name
    origin_id                = "S3-${var.origin_bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.origin_bucket_name}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # SPA fallback: optional custom error response for index.html
  dynamic "custom_error_response" {
    for_each = var.spa_fallback ? [404] : []
    content {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/${var.default_root_object}"
      error_caching_min_ttl = 60
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cdn"
  })
}

# Bucket policy: allow CloudFront OAC to read
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket_policy" "origin" {
  count = var.attach_bucket_policy ? 1 : 0

  bucket = var.origin_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.origin_bucket_name}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}
