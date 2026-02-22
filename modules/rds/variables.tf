variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for RDS"
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security group IDs allowed to connect (e.g. bastion)"
  type        = list(string)
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage (GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Max allocated storage for autoscaling (GB)"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Enable Multi-AZ"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (dev)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
