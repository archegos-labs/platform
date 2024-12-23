include "root" {
  path = find_in_parent_folders()
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.14.0"
}

dependency "account" {
  config_path = "${dirname(find_in_parent_folders())}/account"

  mock_outputs                            = include.mocks.locals.account
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

locals {
  cidr       = "10.0.0.0/16"
  zone_count = 3
}

inputs = {
  name = "${dependency.account.outputs.resource_prefix}-vpc"
  cidr = local.cidr


  /**
    Best Practice: Multi-AZ Deployment
    https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html

    Ensures high availability and fault tolerance.
   */
  azs = slice(dependency.account.outputs.available_azs, 0, 3)

  /**
    Best Practice: Create Public and Private Subnets in Each Availability Zone
    https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html

    Supports node creation in private subnets and ELB creation in public subnets.
   */
  private_subnets = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    cidrsubnet(local.cidr, 8, k + 1)
  ]
  private_subnet_names = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    "${dependency.account.outputs.resource_prefix}-private-subnet-${v}"
  ]
  /**
   * Enables automatic discovery of subnets that an Application Load Balancer uses in Amazon EKS.
   * See: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.11/deploy/subnet_discovery/
   */
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                                         = 1
  }

  public_subnets = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    cidrsubnet(local.cidr, 8, k + 101)
  ]
  public_subnet_names = [
    for k, v in slice(dependency.account.outputs.available_azs, 0, 3) :
    "${dependency.account.outputs.resource_prefix}-public-subnet-${v}"
  ]
  /**
   * Enables automatic discovery of subnets that an Application Load Balancer uses in Amazon EKS
   * See: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.11/deploy/subnet_discovery/
   */
  public_subnet_tags = {
    "kubernetes.io/role/elb"                                                  = 1
  }
  map_public_ip_on_launch = true

  /**
    Best Practice Deploy NAT Gateways in each Availability Zone
    https://docs.aws.amazon.com/eks/latest/best-practices/subnets.html

    Ensures zone-independent architecture and reduces cross AZ expenditures.
   */
  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true

  /**
    Network Requirement: Enable DNS Resolution and DNS Hostnames
    https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html

    Required for nodes to register to your cluster.
  */
  enable_dns_support   = true
  enable_dns_hostnames = true

  create_database_subnet_group = false
}