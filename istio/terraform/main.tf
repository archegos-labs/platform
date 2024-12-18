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

  values = [
    <<-EOT
      meshConfig:
        accessLogFile: /dev/stdout
        defaultConfig:
          proxyMetadata: {}
          tracing: {}
        enablePrometheusMerge: true
        rootNamespace: ${kubernetes_namespace.istio_system.metadata[0].name}
        tcpKeepalive:
          interval: 5s
          probes: 3
          time: 10s
      pilot:
        env:
          CLOUD_PLATFORM: aws
      istio_cni:
        enabled: true
        chained: true
      global:
        istioNamespace:  ${kubernetes_namespace.istio_system.metadata[0].name}
    EOT
  ]

  depends_on = [module.istio_base]
}

module "istio_cni" {
  source = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name          = "istio-cni"
  description   = <<-EOT
    Responsible for detecting the pods that belong to the ambient mesh, and configuring the traffic redirection
    between pods and the ztunnel node proxy"
  EOT

  namespace     = kubernetes_namespace.istio_system.metadata[0].name
  chart         = "cni"
  chart_version = local.istio_repo_version
  repository    = local.istio_repo_url

  wait          = true
  wait_for_jobs = true

  values = [
    <<-EOT
      cni:
        excludeNamespaces:
          - ${kubernetes_namespace.istio_system.metadata[0].name}
          - kube-system
    EOT
  ]

  depends_on = [ module.istio_istiod ]
}