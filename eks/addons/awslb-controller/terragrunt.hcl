/**
  AWS Load Balancer Controller for AWS EKS.

  Docs: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.11/
  More Help: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws-load-balancer-controller.md
  Helm Chart: https://github.com/kubernetes-sigs/aws-load-balancer-controller/tree/main/helm/aws-load-balancer-controller
 */
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
  ]
}

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders())}/vpc"

  mock_outputs                            = include.mocks.locals.vpc
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
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
  vpc_id          = dependency.vpc.outputs.vpc_id
  service_account = "aws-load-balancer-controller-sa"
  monitoring_namespace = "monitoring"
}
