include "root" {
  path = find_in_parent_folders()
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders())}/vpc"
}

dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"
}

terraform {
  source = ".//terraform"
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_version = dependency.eks.outputs.cluster_version
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  vpc_id       = dependency.vpc.outputs.vpc_id
  service_account = "aws-vpc-cni-sa"
}
