generate "kube_provider" {
  path      = "kube-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    # host/CA come from the eks/cluster module outputs (mockable at plan time), so no
    # aws_eks_cluster data source is needed and plan works whether or not the cluster
    # exists. exec mints a fresh token per API call, avoiding the 15-minute EKS token
    # expiry on long applies.
    provider "kubernetes" {
      host                   = var.cluster_endpoint
      cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
      exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = "aws"
        args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      }
    }
  EOF
}