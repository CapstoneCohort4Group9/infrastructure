# modules/networking/main.tf
# This module imports and uses existing VPC resources

# Import existing VPC
data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Enable DNS settings on the VPC for RDS public access
resource "aws_vpc_dhcp_options_association" "dns_resolver" {
  vpc_id          = data.aws_vpc.existing.id
  dhcp_options_id = data.aws_vpc.existing.dhcp_options_id
}

# Enable DNS resolution and DNS hostnames
resource "null_resource" "vpc_dns_settings" {
  triggers = {
    vpc_id = var.vpc_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 modify-vpc-attribute --vpc-id ${var.vpc_id} --enable-dns-hostnames
      aws ec2 modify-vpc-attribute --vpc-id ${var.vpc_id} --enable-dns-support
    EOT
  }
}

# Alternative: Use AWS CLI via local-exec or create a separate script
# Since terraform doesn't have direct resources for modifying existing VPC attributes

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
