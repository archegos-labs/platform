include "root" {
  path = find_in_parent_folders()
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/eks/cluster",
    "${dirname(find_in_parent_folders())}/eks/addons/cert-manager",
    "${dirname(find_in_parent_folders())}/eks/addons/awslb-controller",
  ]
}


dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"

  mock_outputs                            = include.mocks.locals.eks
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

terraform {
  source = ".//terraform"
}

inputs = {
  cluster_name    = dependency.eks.outputs.cluster_name
  service_account = "external-dns-sa"
}
