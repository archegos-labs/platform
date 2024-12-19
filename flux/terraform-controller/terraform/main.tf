# https://flux-iac.github.io/tofu-controller/
module "flux_terraform_controller" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  # https://github.com/flux-iac/tofu-controller/tree/main/charts/tofu-controller
  name             = "flux"
  description      = "A Helm chart to deploy flux-terraform-controller"
  chart            = "tf-controller"
  chart_version    = "v0.16.0-rc.4"
  repository       = "https://flux-iac.github.io/tofu-controller"
  create_namespace = false
  namespace        = "flux-system"

  wait          = true
  wait_for_jobs = true
}

resource "kubernetes_secret" "tf_deployer_aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = "flux-system"
  }
  type = "Opaque"
  data = {
    AWS_ACCESS_KEY_ID     = var.tf_deployer_aws_access_key
    AWS_SECRET_ACCESS_KEY = var.tf_deployer_aws_secret_key
  }
}