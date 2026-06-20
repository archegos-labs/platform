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

dependency "dex" {
  config_path = "${dirname(find_in_parent_folders())}/auth/dex"

  mock_outputs = {
    dex_issuer_uri      = "https://dex.admin.mock.com/dex"
    oidc_client_secrets = { kiali = "mock-secret" }
  }
  mock_outputs_allowed_terraform_commands = include.mocks.locals.commands
}

terraform {
  source = ".//terraform"
}

inputs = {
  cluster_name             = dependency.eks.outputs.cluster_name
  resource_prefix          = dependency.account.outputs.resource_prefix
  kiali_oidc_client_secret = dependency.dex.outputs.oidc_client_secrets["kiali"]
  dex_issuer_uri           = dependency.dex.outputs.dex_issuer_uri
  root_domain              = dependency.account.outputs.root_domain
}
