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
  chart_version    = "v2.26.0"
  repository       = "https://kiali.org/helm-charts"

  // CR spec: https://kiali.io/docs/configuration/kialis.kiali.io/
  values = [
    <<-EOF
    cr:
      create: true
      namespace: ${var.istio_namespace}
      spec:
        auth:
          strategy: openid
          openid:
            client_id: "kiali"
            issuer_uri: "${var.dex_issuer_uri}"
            disable_rbac: true
        istio_namespace: ${var.istio_namespace}
        external_services:
          prometheus:
            url: "http://prometheus-operated.${var.prometheus_namespace}:9090"
          grafana:
            enabled: true
            internal_url: "http://prometheus-grafana.${var.prometheus_namespace}:80"
            external_url: "https://grafana.admin.${local.root_domain}"
    EOF
  ]
}

resource "kubernetes_secret_v1" "kiali_oidc" {
  metadata {
    name      = "kiali"
    namespace = var.istio_namespace
  }

  data = {
    "oidc-secret" = var.kiali_oidc_client_secret
  }
}

locals {
  root_domain = var.root_domain
  app_domain  = "kiali.admin.${local.root_domain}"
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = local.app_domain
  zone_id     = var.root_zone_id

  validation_method = "DNS"
}

resource "kubernetes_ingress_v1" "kiali_ingress" {
  metadata {
    name      = "kiali-ingress"
    namespace = var.istio_namespace
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname"      = local.app_domain
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/kiali/healthz"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
      "alb.ingress.kubernetes.io/group.name"           = "${var.resource_prefix}-alb"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"         = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({ "Type" : "redirect", "RedirectConfig" : { "Protocol" : "HTTPS", "Port" : "443", "StatusCode" : "HTTP_301" } })
      "alb.ingress.kubernetes.io/inbound-cidrs"        = "0.0.0.0/0"
      # No need to declare certificate: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/cert_discovery/
    }
  }

  spec {
    ingress_class_name = "alb"

    tls {
      hosts = [local.app_domain]
    }

    // taken from https://www.stacksimplify.com/aws-eks/aws-alb-ingress/learn-to-enable-ssl-redirect-in-alb-ingress-service-on-aws-eks/
    rule {
      host = local.app_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "ssl-redirect"

              port {
                name = "use-annotation"
              }
            }
          }
        }
      }
    }

    rule {
      host = local.app_domain

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "kiali"

              port {
                # Kiali uses port 20001 by default. We reference the service port name here.
                # https://github.com/kiali/helm-charts/blob/master/kiali-server/values.yaml#L119C9-L119C14
                name = "http"
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  depends_on = [module.acm, module.kiali_operator, kubernetes_secret_v1.kiali_oidc]
}
