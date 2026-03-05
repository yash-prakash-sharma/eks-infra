variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "origin_bucket_name" {
  description = "S3 bucket name (origin)"
  type        = string
}

variable "origin_bucket_regional_domain_name" {
  description = "S3 bucket regional domain name (e.g. bucket.s3.region.amazonaws.com)"
  type        = string
}

variable "default_root_object" {
  description = "Default root object (e.g. index.html)"
  type        = string
  default     = "index.html"
}

variable "comment" {
  description = "CloudFront distribution comment"
  type        = string
  default     = "Frontend CDN"
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "spa_fallback" {
  description = "Return index.html for 404 (SPA routing)"
  type        = bool
  default     = true
}

variable "attach_bucket_policy" {
  description = "Attach policy to origin bucket allowing CloudFront"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
