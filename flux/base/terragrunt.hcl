include "root" {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"
}

generate "providers" {
  path = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
  terraform {
    required_providers {
      flux = {
        source  = "fluxcd/flux"
        version = ">= 1.4"
      }
      github = {
        source  = "integrations/github"
        version = ">= 6.3"
      }
      tls = {
        source  = "hashicorp/tls"
        version = ">= 4.0"
      }
    }
  }
  EOF
}

terraform {
  source = ".//terraform"

  extra_arguments "deploy" {
    commands = [
      "init",
      "apply",
      "destroy",
      "refresh",
      "import",
      "plan",
      "taint",
      "untaint"
    ]

    env_vars = {
      TF_VAR_github_pat = get_env("ARCHEGOS_FLUX_GITHUB_TOKEN")
    }
  }
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  cluster_endpoint = dependency.eks.outputs.cluster_endpoint
  cluster_certificate_authority_data = dependency.eks.outputs.cluster_certificate_authority_data
  github_org = "archegos-solutions"
  github_repository = "fluxcd"
}
