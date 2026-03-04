variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "oidc_provider_url" {
  description = "OIDC provider URL for EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for EKS cluster"
  type        = string
}
