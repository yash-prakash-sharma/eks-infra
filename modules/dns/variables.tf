variable "domain_name" {
  description = "The custom domain name for the environment (e.g. hostinger domain)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to DNS resources"
  type        = map(string)
  default     = {}
}
