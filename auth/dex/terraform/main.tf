locals {
  release_name = "dex-new"
  namespace    = "auth"
  dex_host     = "dex.admin.${var.root_domain}"
  issuer_uri   = "https://${local.dex_host}/dex"
}

resource "random_password" "dex_admin" {
  length  = 20
  special = false
}

resource "random_password" "oidc_client_secret" {
  for_each = { for c in var.oidc_clients : c.id => c }

  length  = 32
  special = false
}

resource "helm_release" "dex" {
  name             = local.release_name
  chart            = "../charts/dex"
  namespace        = local.namespace
  create_namespace = true

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  values = [
    yamlencode({
      namespace = local.namespace
      issuer    = local.issuer_uri
      admin = {
        email    = var.admin_email
        username = "admin"
        hash     = random_password.dex_admin.bcrypt_hash
      }
      staticClients = [
        for c in var.oidc_clients : {
          id           = c.id
          name         = c.name
          secret       = random_password.oidc_client_secret[c.id].result
          redirectURIs = [c.redirect_uri]
        }
      ]
    })
  ]
}

data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 6.0"

  domain_name       = local.dex_host
  zone_id           = data.aws_route53_zone.root.zone_id
  validation_method = "DNS"
}

resource "kubernetes_ingress_v1" "dex" {
  metadata {
    name      = "dex-ingress"
    namespace = local.namespace
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname"      = local.dex_host
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/dex/.well-known/openid-configuration"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
      "alb.ingress.kubernetes.io/group.name"           = "${var.resource_prefix}-alb"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"         = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({ "Type" : "redirect", "RedirectConfig" : { "Protocol" : "HTTPS", "Port" : "443", "StatusCode" : "HTTP_301" } })
      "alb.ingress.kubernetes.io/inbound-cidrs" = "0.0.0.0/0"
    }
  }

  spec {
    ingress_class_name = "alb"

    tls {
      hosts = [local.dex_host]
    }

    rule {
      host = local.dex_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ssl-redirect"
              port { name = "use-annotation" }
            }
          }
        }
      }
    }

    rule {
      host = local.dex_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = local.release_name
              port { number = 5556 }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true
  depends_on             = [module.acm, helm_release.dex]
}