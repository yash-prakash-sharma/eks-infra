variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
variable "cluster_name" {
  description = "EKS Cluster Name for Pod Identity Binding"
  type        = string
}
