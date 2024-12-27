/**
 Docs: https://github.com/kubernetes-sigs/aws-fsx-csi-driver/tree/master
 */
include "root" {
  path = find_in_parent_folders()
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/eks/cluster",
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
  cluster_name               = dependency.eks.outputs.cluster_name
  cluster_version            = dependency.eks.outputs.cluster_version
  controller_service_account = "fsx-csi-controller-sa"
  node_service_account       = "fsx-csi-node-sa"
}
