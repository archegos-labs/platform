include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.14.0"
}

dependency "account" {
  config_path = "${dirname(find_in_parent_folders())}/account"

  mock_outputs = {
    resource_prefix = "mock-resource-prefix"
    available_azs   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  }

  mock_outputs_allowed_terraform_commands = ["init", "plan"]
}

locals {
  cidr       = "10.0.0.0/16"
  zone_count = 3
}

inputs = {
  name = "${dependency.account.outputs.resource_prefix}-vpc"
  cidr = local.cidr

  azs = slice(dependency.account.outputs.available_azs, 0, 3)
  private_subnets = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    cidrsubnet(local.cidr, 8, k + 1)
  ]
  private_subnet_names = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    "${dependency.account.outputs.resource_prefix}-private-subnet-${v}"
  ]
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                         = 1
    "kubernetes.io/cluster/${dependency.account.outputs.resource_prefix}-vpc" = "shared"
  }

  public_subnets = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    cidrsubnet(local.cidr, 8, k + 101)
  ]
  public_subnet_names = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    "${dependency.account.outputs.resource_prefix}-public-subnet-${v}"
  ]
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                                  = 1
    "kubernetes.io/cluster/${dependency.account.outputs.resource_prefix}-eks" = "shared"
  }
  map_public_ip_on_launch = true

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  create_database_subnet_group = false
}