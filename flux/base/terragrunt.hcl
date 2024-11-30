include "root" {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "${dirname(find_in_parent_folders())}/eks/cluster"
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
