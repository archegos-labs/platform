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
    "${dirname(find_in_parent_folders())}/eks/addons/external-dns",
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

terraform {
  source = ".//terraform"
}

inputs = {
  cluster_name                       = dependency.eks.outputs.cluster_name
  cluster_endpoint                   = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  resource_prefix                    = dependency.account.outputs.resource_prefix
  root_domain                        = dependency.account.outputs.root_domain
  root_zone_id                       = dependency.account.outputs.root_zone_id
  admin_email                        = dependency.account.outputs.admin_email

  # Static OIDC clients registered with Dex. Redirect URIs are kept here (not
  # derived from consumer modules) so consumers can depend on Dex without
  # creating a circular dependency. If a consumer's hostname changes, update
  # both this list and the consumer's terragrunt inputs in the same change.
  oidc_clients = [
    {
      id           = "kiali"
      name         = "Kiali"
      redirect_uri = "https://kiali.admin.${dependency.account.outputs.root_domain}/kiali"
    },
    {
      id           = "kubeflow-oidc-authservice"
      name         = "Kubeflow OAuth2 Proxy"
      redirect_uri = "https://dashboard.admin.${dependency.account.outputs.root_domain}/oauth2/callback"
    },
    {
      id           = "grafana"
      name         = "Grafana"
      redirect_uri = "https://grafana.admin.${dependency.account.outputs.root_domain}/login/generic_oauth"
    },
  ]
}