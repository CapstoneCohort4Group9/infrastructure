# modules/networking/main.tf
# This module imports and uses existing VPC resources

# Import existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Import existing subnets
data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = toset(length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : var.public_subnet_ids)
  id       = each.value
}

# Import existing Internet Gateway
data "aws_internet_gateway" "existing" {
  internet_gateway_id = var.internet_gateway_id
}

# Get availability zones for the subnets
data "aws_availability_zones" "available" {
  state = "available"
}