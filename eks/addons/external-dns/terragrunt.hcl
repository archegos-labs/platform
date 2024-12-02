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
    "../cert-manager",
    "../awslb-controller",
  ]
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
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  service_account                    = "external-dns-sa"
}
