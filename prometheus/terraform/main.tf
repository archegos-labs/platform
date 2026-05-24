resource "helm_release" "prometheus" {
  name             = "prometheus"
  description      = "Prometheus monitoring stack"
  chart            = "kube-prometheus-stack"
  namespace        = var.prometheus_namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  version          = "v76.4.0"

  atomic        = true
  recreate_pods = true

  cleanup_on_fail = true
  values = [
    <<EOF
    alertmanager:
      enabled: false
    EOF
  ]
}

locals {
  root_domain = "aedenjameson.com"
  app_domain  = "grafana.admin.${local.root_domain}"
}

data "aws_route53_zone" "aedenjameson_com" {
  name         = local.root_domain
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name = local.app_domain
  zone_id     = data.aws_route53_zone.aedenjameson_com.zone_id

  validation_method = "DNS"
}

resource "kubernetes_ingress_v1" "grafana_ingress" {
  metadata {
    name      = "grafana-ingress"
    namespace = var.prometheus_namespace
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname"      = local.app_domain
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/api/health"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
      "alb.ingress.kubernetes.io/group.name"           = "${var.resource_prefix}-alb"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"         = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({ "Type" : "redirect", "RedirectConfig" : { "Protocol" : "HTTPS", "Port" : "443", "StatusCode" : "HTTP_301" } })
      "alb.ingress.kubernetes.io/inbound-cidrs"        = "0.0.0.0/0" # NOTE: this is highly recommended when using an internet-facing ALB
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
              name = "prometheus-grafana"

              port {
                # Grafana uses port 3000 by default. We reference the service port name here.
                name = "http-web"
              }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true

  depends_on = [module.acm, helm_release.prometheus]
}
