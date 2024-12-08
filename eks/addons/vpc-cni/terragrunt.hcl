include "root" {
  path = find_in_parent_folders()
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/vpc",
    "${dirname(find_in_parent_folders())}/eks/cluster",
  ]
}

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders())}/vpc"

  mock_outputs = {
    vpc_id = "mock-vpc-1234567890abcdef0"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
}

dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"

  mock_outputs = {
    cluster_name                       = "mock-cluster-name"
    cluster_version                    = "1.31"
    cluster_endpoint                   = "mock-cluster-endpoint"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
}

terraform {
  source = ".//terraform"
}

inputs = {
  vpc_id                             = dependency.vpc.outputs.vpc_id
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_version                    = dependency.eks.outputs.cluster_version
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  service_account                    = "aws-vpc-cni-sa"
}
