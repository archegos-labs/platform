# https://flux-iac.github.io/tofu-controller/
module "flux_terraform_controller" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  # https://github.com/flux-iac/tofu-controller/tree/main/charts/tofu-controller
  name             = "flux"
  description      = "A Helm chart to deploy flux-terraform-controller"
  chart = "tf-controller"
  chart_version    = "v0.16.0-rc.4"
  repository       = "https://flux-iac.github.io/tofu-controller"
  create_namespace = false
  namespace        = "flux-system"

  wait                       = true
  wait_for_jobs              = true
}
