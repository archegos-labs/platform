include "root" {
  path = find_in_parent_folders()
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
}

include "kube_provider" {
  path = "${dirname(find_in_parent_folders())}/common/kube-provider.hcl"
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/eks/cluster",
    "${dirname(find_in_parent_folders())}/eks/addons/cert-manager",
    "${dirname(find_in_parent_folders())}/eks/addons/awslb-controller",
    "${dirname(find_in_parent_folders())}/prometheus",
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
  cluster_name = dependency.eks.outputs.cluster_name
}
