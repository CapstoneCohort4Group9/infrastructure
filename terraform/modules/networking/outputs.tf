# modules/networking/outputs.tf
output "vpc_id" {
  description = "VPC ID"
  value       = data.aws_vpc.existing.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = data.aws_vpc.existing.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = var.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : var.public_subnet_ids
}

output "availability_zones" {
  description = "List of availability zones"
  value       = distinct([for s in data.aws_subnet.public : s.availability_zone])
}
