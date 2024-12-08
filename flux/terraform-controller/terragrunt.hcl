include "root" {
  path = find_in_parent_folders()
}

include "helm_provider" {
  path = "${dirname(find_in_parent_folders())}/common/helm-provider.hcl"
}

include "kube_provider" {
  path = "${dirname(find_in_parent_folders())}/common/kube-provider.hcl"
}

include "mocks" {
  path   = "${dirname(find_in_parent_folders())}/common/mocks.hcl"
  expose = true
}

dependencies {
  paths = [
    "${dirname(find_in_parent_folders())}/eks/cluster",
    "${dirname(find_in_parent_folders())}/flux/base"
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

locals {
  tf_deployer_aws_access_key = get_env("TF_DEPLOYER_AWS_ACCESS_KEY")
  tf_deployer_aws_secret_key = get_env("TF_DEPLOYER_AWS_SECRET_KEY")
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  tf_deployer_aws_access_key         = local.tf_deployer_aws_access_key
  tf_deployer_aws_secret_key         = local.tf_deployer_aws_secret_key
}
