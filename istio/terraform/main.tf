locals {
  istio_repo_url = "https://istio-release.storage.googleapis.com/charts"
  istio_repo_version = "1.24.1"
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

module "istio_base" {
  source = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name          = "istio-base"
  description   = "Contains the basic CRDs and cluster roles required to set up Istio."
  namespace     = kubernetes_namespace.istio_system.metadata[0].name
  chart         = "base"
  chart_version = local.istio_repo_version
  repository    = local.istio_repo_url

  wait          = true
  wait_for_jobs = true
}