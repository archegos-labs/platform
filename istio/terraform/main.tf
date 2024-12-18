locals {
  istio_repo_url = "https://istio-release.storage.googleapis.com/charts"
  istio_repo_version = "1.24.1"
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

// https://istio.io/latest/docs/ambient/install/helm/#base-components
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

// https://istio.io/latest/docs/ambient/install/helm/#istiod-control-plane
module "istio_istiod" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name          = "istio-istiod"
  description   = "The control plane component that manages and configures the proxies to route traffic within the mesh."
  namespace     = kubernetes_namespace.istio_system.metadata[0].name
  chart         = "istiod"
  chart_version = local.istio_repo_version
  repository    = local.istio_repo_url

  wait          = true
  wait_for_jobs = true

  set = [
    {
      name  = "meshConfig.accessLogFile"
      value = "/dev/stdout"
    }
  ]

  depends_on = [module.istio_base]
}