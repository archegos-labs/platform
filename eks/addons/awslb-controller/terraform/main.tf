
locals {
  namespace = "kube-system"
}

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.6.1"

  name = var.service_account

  attach_aws_lb_controller_policy = true

  associations = {
    "aws-load-balancer-controller" = {
      cluster_name    = var.cluster_name
      namespace       = local.namespace
      service_account = var.service_account
    }
  }
}

module "eks_blueprints_addon" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name        = "aws-load-balancer-controller"
  description = "A Helm chart to deploy aws-load-balancer-controller"

  chart            = "aws-load-balancer-controller"
  chart_version    = "1.11.0"
  repository       = "https://aws.github.io/eks-charts"
  namespace        = local.namespace
  create_namespace = false

  wait          = true
  wait_for_jobs = true

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = var.service_account
    },
    {
      name  = "podDisruptionBudget.maxUnavailable"
      value = 1
    },
    {
      name  = "enableServiceMutatorWebhook"
      value = "false"
    }
  ]
}