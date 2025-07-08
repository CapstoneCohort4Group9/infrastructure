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

output "vpc_dns_support_enabled" {
  description = "Whether DNS resolution is enabled"
  value       = data.aws_vpc.existing.enable_dns_support
}

output "vpc_dns_hostnames_enabled" {
  description = "Whether DNS hostnames are enabled"
  value       = data.aws_vpc.existing.enable_dns_hostnames
}