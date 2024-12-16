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

data "aws_eks_addon_version" "latest" {
  addon_name         = local.addon_name
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "aws_fsx_csi" {
  cluster_name = var.cluster_name
  addon_name   = local.addon_name
  addon_version = data.aws_eks_addon_version.latest.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [module.aws_fsx_lustre_csi_pod_identity]
}
