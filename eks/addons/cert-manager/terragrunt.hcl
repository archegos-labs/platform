include "root" {
  path = find_in_parent_folders()
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

include "kube_provider" {
  path = "${dirname(find_in_parent_folders())}/common/kube-provider.hcl"
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/vpc",
    "${dirname(find_in_parent_folders())}/eks/cluster",
  ]
}

dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"

  mock_outputs = {
    cluster_name                       = "mock-cluster-name"
    cluster_endpoint                   = "mock-cluster-endpoint"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCg=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan"]
}

terraform {
  source = ".//terraform"
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  service_account                    = "cert-manager-sa"
}
