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

    provider "kubernetes" {
        host                   = var.kube_data_auth_enabled ? one(data.aws_eks_cluster.this_kube[*].endpoint) : null
        cluster_ca_certificate = var.kube_data_auth_enabled ? base64decode(one(data.aws_eks_cluster.this_kube[*].certificate_authority[0].data)) : null
        # exec fetches a fresh token per API call, avoiding the 15-minute EKS token expiry
        # on long applies. Gated on the same flag as host/CA so the disabled path (plan)
        # falls back to the local kubeconfig context instead of forcing aws eks get-token.
        dynamic "exec" {
          for_each = var.kube_data_auth_enabled ? [1] : []
          content {
            api_version = "client.authentication.k8s.io/v1beta1"
            command     = "aws"
            args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
          }
        }
    }
  EOF
}
