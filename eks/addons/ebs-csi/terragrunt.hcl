/**
 * Docs: https://github.com/kubernetes-sigs/aws-ebs-csi-driver
 */
include "root" {
  path = find_in_parent_folders()
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
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
  cluster_name    = dependency.eks.outputs.cluster_name
  cluster_version = dependency.eks.outputs.cluster_version
  service_account = "ebs-csi-controller-sa"
}
