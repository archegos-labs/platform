locals {
  namespace = "kube-system"
  addon_name = "aws-fsx-csi-driver"
}

module "aws_fsx_lustre_csi_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.6.1"

  name = "aws-fsx-lustre-csi"

  attach_aws_fsx_lustre_csi_policy     = true
  aws_fsx_lustre_csi_service_role_arns = ["arn:aws:iam::*:role/aws-service-role/s3.data-source.lustre.fsx.amazonaws.com/*"]

  associations = {
    "efs-csi-driver" = {
      cluster_name = var.cluster_name
      namespace       = local.namespace
      service_account = var.service_account
    }
  }
}

// Docs: https://github.com/kubernetes-sigs/aws-fsx-csi-driver
module "aws-fsx-csi" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"


  # https://github.com/kubernetes-sigs/aws-fsx-csi-driver/blob/master/charts/aws-fsx-csi-driver/Chart.yaml
  name             = local.addon_name
  description      = "A Helm chart to deploy aws-fsx-csi-driver"
  namespace        = local.namespace
  create_namespace = false
  chart            = local.addon_name
  chart_version    = "1.9.2"
  repository       = "https://kubernetes-sigs.github.io/aws-fsx-csi-driver"

  wait                       = true
  wait_for_jobs              = true

  set = [
    {
      name  = "controller.serviceAccount.create"
      value = true
    },
    {
      name  = "controller.serviceAccount.name"
      value = var.service_account
    },
    {
      name  = "node.serviceAccount.create"
      value = false
    },
    {
      name  = "node.serviceAccount.name"
      value = var.service_account
    }
  ]
}
