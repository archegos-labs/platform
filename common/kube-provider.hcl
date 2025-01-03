generate "kube_provider" {
  path      = "kube-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    # The reason there are so many "enabled" inputs rather than automatically
    # detecting whether or not they are enabled based on the value of the input
    # Any logic based on data sources requires the values to be known during
    # the "plan" phase of Terraform, and often they are not, which causes problems.

    data "aws_eks_cluster" "this_kube" {
      count = var.kube_data_auth_enabled ? 1 : 0
      name = var.cluster_name
    }

    data "aws_eks_cluster_auth" "this_kube" {
      count = var.kube_data_auth_enabled ? 1 : 0
      name = var.cluster_name
    }

    provider "kubernetes" {
        host                   = var.kube_data_auth_enabled ? one(data.aws_eks_cluster.this_kube[*].endpoint) : null
        cluster_ca_certificate = var.kube_data_auth_enabled ? base64decode(one(data.aws_eks_cluster.this_kube[*].certificate_authority[0].data)) : null
        token                  = var.kube_data_auth_enabled ? one(data.aws_eks_cluster_auth.this_kube[*].token) : null
    }
  EOF
}
