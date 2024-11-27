locals {
  namespace = "kube-system"
}

module "external_dns_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.6.1"

  name = var.service_account

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  associations = {
    "external-dns" = {
      cluster_name   = var.cluster_name
      namespace      = local.namespace
      service_account = var.service_account
    }
  }
}

/**
  AWS Tutorial: https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/aws.md
  Docs: https://kubernetes-sigs.github.io/external-dns/latest/
 */
module "external_dns" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  # https://github.com/kubernetes-sigs/external-dns/tree/master/charts/external-dns/Chart.yaml
  name             = "external-dns"
  description      = "A Helm chart to deploy external-dns"
  namespace        = local.namespace
  create_namespace = false
  chart            = "external-dns"
  chart_version    = "1.15.0"
  repository       = "https://kubernetes-sigs.github.io/external-dns/"
  values           = ["provider: aws", "source: ingress"]

  wait                       = true
  wait_for_jobs              = true

  set = [
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