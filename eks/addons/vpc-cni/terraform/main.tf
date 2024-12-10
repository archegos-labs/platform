locals {
  namespace = "kube-system"
  addon_name = "vpc-cni"
}

module "aws_vpc_cni_ipv4_pod_identity" {
  source = "terraform-aws-modules/eks-pod-identity/aws"
  version = "1.6.1"

  name = var.service_account

  attach_aws_vpc_cni_policy = true
  aws_vpc_cni_enable_ipv4   = true

  associations = {
    "aws_vpc_cni_ipv4" = {
      cluster_name = var.cluster_name
      namespace = local.namespace

      # The VPC-CNI plugin is installed by default when creating an eks cluster and
      # creates kube service account named "aws-node". We re-use this service account
      # here for the EKS Pod Identity association.
      service_account = "aws-node"
    }
  }
}

data "aws_eks_addon_version" "latest" {
  addon_name         = local.addon_name
  kubernetes_version = var.cluster_version
  most_recent        = true
}

# For more, https://github.com/aws/amazon-vpc-cni-k8s
# https://github.com/aws/eks-charts/tree/master/stable/aws-vpc-cni#adopting-the-existing-aws-node-resources-in-an-eks-cluster
resource "aws_eks_addon" "aws_vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = local.addon_name
  addon_version = data.aws_eks_addon_version.latest.version

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [module.aws_vpc_cni_ipv4_pod_identity]
}
