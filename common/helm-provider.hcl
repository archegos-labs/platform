generate "helm_provider" {
  path = "helm-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
    provider "helm" {
      kubernetes {
        host                   = var.cluster_endpoint
        cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
        exec {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          # This requires the awscli to be installed locally where Terraform is executed
          args = ["eks", "get-token", "--cluster-name", var.cluster_name]
        }
      }
    }
  EOF
}
