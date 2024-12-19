locals {
  namespace = "cert-manager"
}

module "cert_manager_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.6.1"

  name                          = var.service_account
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  associations = {
    "cert-manager" = {
      cluster_name    = var.cluster_name
      namespace       = local.namespace
      service_account = var.service_account
    }
  }
}

# For more, https://cert-manager.io/docs/
module "cert_manager" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  # https://github.com/cert-manager/cert-manager/blob/master/deploy/charts/cert-manager/Chart.template.yaml
  name             = "cert-manager"
  description      = "A Helm chart to deploy cert-manager"
  namespace        = local.namespace
  create_namespace = true
  chart            = "cert-manager"
  chart_version    = "v1.14.3"
  repository       = "https://charts.jetstack.io"

  wait          = true
  wait_for_jobs = true

  set = [
    {
      name  = "installCRDs"
      value = true
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = var.service_account
    }
  ]
}
