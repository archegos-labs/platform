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
    "${dirname(find_in_parent_folders())}/vpc",
    "${dirname(find_in_parent_folders())}/eks/cluster",
    "${dirname(find_in_parent_folders())}/eks/addons/cert-manager",
    "${dirname(find_in_parent_folders())}/istio/system",
    "${dirname(find_in_parent_folders())}/auth/dex",
  ]
}

dependency "account" {
  config_path = "${dirname(find_in_parent_folders())}/account"

  mock_outputs                            = include.mocks.locals.account
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"

  mock_outputs                            = include.mocks.locals.eks
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

dependency "vpc" {
  config_path = "${dirname(find_in_parent_folders())}/vpc"

  mock_outputs                            = include.mocks.locals.vpc
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

dependency "dex" {
  config_path = "${dirname(find_in_parent_folders())}/auth/dex"

  mock_outputs = {
    dex_issuer_uri      = "https://dex.admin.mock.com/dex"
    dex_internal_url    = "dex-new.auth.svc.cluster.local:5556"
    oidc_client_secrets = { "kubeflow-oidc-authservice" = "mock-secret" }
  }
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

terraform {
  source = ".//terraform"
}

inputs = {
  vpc_id                             = dependency.vpc.outputs.vpc_id
  vpc_cidr_block                     = dependency.vpc.outputs.vpc_cidr_block
  private_subnets                    = dependency.vpc.outputs.private_subnets
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  resource_prefix                    = dependency.account.outputs.resource_prefix
  root_domain                        = dependency.account.outputs.root_domain
  root_zone_id                       = dependency.account.outputs.root_zone_id
  admin_email                        = dependency.account.outputs.admin_email
  dex_issuer_uri                     = dependency.dex.outputs.dex_issuer_uri
  dex_internal_url                   = dependency.dex.outputs.dex_internal_url
  kubeflow_oidc_client_secret        = dependency.dex.outputs.oidc_client_secrets["kubeflow-oidc-authservice"]
}