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

# Cluster-default StorageClass. EKS ships a legacy in-tree `gp2` class that is NOT marked
# default, so PVCs without an explicit storageClassName (e.g. Kubeflow notebook workspaces)
# fail to provision. This gp3 class uses the EBS CSI driver, is encrypted, and is the default.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [aws_eks_addon.aws_ebs_csi]
}

