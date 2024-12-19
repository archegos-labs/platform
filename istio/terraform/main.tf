locals {
  istio_repo_url     = "https://istio-release.storage.googleapis.com/charts"
  istio_repo_version = "1.24.1"
}

resource "kubernetes_namespace" "istio_system" {
  metadata {
    name = "istio-system"
  }
}

// https://istio.io/latest/docs/ambient/install/helm/#base-components
module "istio_base" {
  source  = "aws-ia/eks-blueprints-addon/aws"
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
          PILOT_ENABLE_AMBIENT: true
          CLOUD_PLATFORM: aws
      istio_cni:
        enabled: true
        chained: true
      global:
        istioNamespace:  ${kubernetes_namespace.istio_system.metadata[0].name}
      profile: ambient
    EOT
  ]

  depends_on = [module.istio_base]
}

// https://istio.io/latest/docs/setup/additional-setup/cni/
module "istio_cni" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name        = "istio-cni"
  description = <<-EOT
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
      profile: ambient
      cni:
        excludeNamespaces:
          - ${kubernetes_namespace.istio_system.metadata[0].name}
          - kube-system
    EOT
  ]

  depends_on = [module.istio_istiod]
}

module "istio_ztunnel" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name          = "istio-ztunnel"
  description   = "The node proxy component of Istio’s ambient mode."
  namespace     = kubernetes_namespace.istio_system.metadata[0].name
  chart         = "ztunnel"
  chart_version = local.istio_repo_version
  repository    = local.istio_repo_url

  wait          = true
  wait_for_jobs = true

  depends_on = [module.istio_cni]
}

resource "kubernetes_namespace" "istio_ingress" {
  metadata {
    labels = {
      istio-injection = "enabled"
    }

    name = var.ingress_namespace
  }
}

/**
   Remember to run the following after installing the istio-ingress gateway:

   ```bash
   kubectl rollout restart deployment istio-ingress -n istio-ingress
    ```
 */
// https://istio.io/latest/docs/setup/additional-setup/gateway/
module "istio_ingress" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name          = "istio-ingress"
  description   = "Provides Envoy proxies running at the edge of the mesh, providing fine-grained control over traffic entering and leaving the mesh."
  namespace     = kubernetes_namespace.istio_ingress.metadata[0].name
  chart         = "gateway"
  chart_version = local.istio_repo_version
  repository    = local.istio_repo_url

  values = [
    yamlencode(
      {
        labels = {
          istio = "ingressgateway"
        }
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
            "service.beta.kubernetes.io/aws-load-balancer-type"             = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type"  = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"           = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-attributes"       = "load_balancing.cross_zone.enabled=true"
          }
        }
      }
    )
  ]

  wait          = true
  wait_for_jobs = true

  depends_on = [module.istio_ztunnel, module.istio_cni]
}



/**
 * https://kiali.io/docs/installation/installation-guide/creating-updating-kiali-cr/
 *
 * The Kiali Operator watches the Kiali Custom Resource (Kiali CR), a custom resource that contains the
 * Kiali Server deployment configuration. Creating, updating, or removing a Kiali CR will trigger the Kiali Operator
 * to install, update, or remove Kiali.
 */
module "kiali_operator" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name             = "kiali-operator"
  description      = "Kiali is a console for Istio service mesh"
  namespace        = "kiali-operator"
  create_namespace = true
  chart            = "kiali-operator"
  chart_version    = "v2.2.0"
  repository       = "https://kiali.org/helm-charts"

  // CR spec: https://kiali.io/docs/configuration/kialis.kiali.io/
  values = [
    <<-EOF
    cr:
      create: true
      namespace: ${kubernetes_namespace.istio_system.metadata[0].name}
      spec:
        auth:
          strategy: anonymous
        istio_namespace: ${kubernetes_namespace.istio_system.metadata[0].name}
    EOF
  ]
}