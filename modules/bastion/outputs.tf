output "instance_id" {
  description = "Bastion instance ID"
  value       = aws_instance.bastion.id
}

output "public_ip" {
  description = "Bastion public IP"
  value       = aws_instance.bastion.public_ip
}

output "security_group_id" {
  description = "Bastion security group ID (use for RDS allowed_sg)"
  value       = aws_security_group.bastion.id
}
