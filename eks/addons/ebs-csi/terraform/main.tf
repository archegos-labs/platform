locals {
  addon_name = "aws-ebs-csi-driver"
}

module "aws_ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.0.0"

  name = var.service_account

  attach_aws_ebs_csi_policy = true
}

data "aws_eks_addon_version" "snapshot_controller_latest" {
  addon_name         = "snapshot-controller"
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "snapshot_controller" {
  cluster_name  = var.cluster_name
  addon_name    = "snapshot-controller"
  addon_version = data.aws_eks_addon_version.snapshot_controller_latest.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
}

data "aws_eks_addon_version" "ebs_csi_latest" {
  addon_name         = local.addon_name
  kubernetes_version = var.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "aws_ebs_csi" {
  cluster_name  = var.cluster_name
  addon_name    = local.addon_name
  addon_version = data.aws_eks_addon_version.ebs_csi_latest.version

  pod_identity_association {
    role_arn        = module.aws_ebs_csi_pod_identity.iam_role_arn
    service_account = var.service_account
  }

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_addon.snapshot_controller]
}

