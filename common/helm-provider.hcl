generate "helm_provider" {
  path      = "helm-provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    data "aws_eks_cluster" "this" {
      name = var.cluster_name
    }

    data "aws_eks_cluster_auth" "this" {
      name = var.cluster_name
    }

    provider "helm" {
      kubernetes {
        host                   = data.aws_eks_cluster.this.endpoint
        cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
        token                  = data.aws_eks_cluster_auth.this.token
      }
    }
  EOF
}
