locals {
  dashboard_host = "dashboard.admin.${var.root_domain}"
  # Single source of truth for the admin profile namespace. Used by the profiles
  # release (Profile/namespace name) and the pipelines release (profile_namespaces,
  # which scopes the ml-pipeline AuthorizationPolicy to that namespace's
  # default-editor). Keep these in sync via this local.
  admin_profile_namespace = "kubeflow-admin"
}

resource "kubernetes_namespace" "kubeflow" {
  metadata {
    labels = {
      control-plane = "kubeflow"
      # Ambient mesh: ztunnel handles this namespace's pods. Do not add
      # istio-injection=enabled here — that opts the namespace into sidecar
      # injection, which conflicts with ambient (sidecars win and exclude the
      # pods from ztunnel). Sidecar injection is used intentionally elsewhere,
      # e.g. the `ingress` namespace for the gateway.
      "istio.io/dataplane-mode" = "ambient"
      # No PSS enforcement label here. In ambient mode istio-cni does traffic
      # redirection at the node level, so these pods don't need the per-pod
      # NET_ADMIN/NET_RAW init container that sidecar mode required — the
      # original Istio blocker no longer applies. Revisit enabling baseline/
      # restricted once the Kubeflow workloads here are confirmed compatible.
    }

    name = "kubeflow"
  }
}

resource "kubernetes_namespace" "kubeflow_system" {
  metadata {
    labels = {
      control-plane                        = "kubeflow"
      "pod-security.kubernetes.io/enforce" = "baseline"
    }

    name = "kubeflow-system"
  }
}

resource "helm_release" "kubeflow_issuer" {
  name        = "kubeflow-issuer"
  description = "A Helm chart to deploy kubeflow-issuer"
  chart       = "../charts/kubeflow-issuer"

  wait          = true
  wait_for_jobs = true

  depends_on = [kubernetes_namespace.kubeflow]
}

resource "helm_release" "kubeflow_roles" {
  name        = "kubeflow-roles"
  description = "Kubeflow base aggregated ClusterRoles (kubeflow-admin/edit/view)"
  chart       = "../charts/kubeflow-roles"
  namespace   = kubernetes_namespace.kubeflow.metadata[0].name

  wait          = true
  wait_for_jobs = true

  depends_on = [kubernetes_namespace.kubeflow]
}

resource "random_password" "minio_access_key" {
  length  = 16
  special = false
}

resource "random_password" "minio_secret_key" {
  length  = 32
  special = false
}

resource "helm_release" "istio_ingress" {
  name             = "istio-ingress"
  chart            = "../charts/istio-ingress"
  namespace        = "ingress"
  create_namespace = true

  values = [
    <<-EOT
      ingress:
        namespace: "ingress"
        gateway: "ingress-gateway"
      healthcheck:
        port: 8080
        path: "/healthcheck"
      cluster_issuer:
        name: "cluster-self-signing-issuer"
    EOT
  ]

  depends_on = [helm_release.kubeflow_issuer]
}

#######################################
# Kubeflow Trainer
#######################################
resource "helm_release" "kubeflow_trainer" {
  name       = "kubeflow-trainer"
  namespace  = kubernetes_namespace.kubeflow_system.metadata[0].name
  repository = "oci://ghcr.io/kubeflow/charts"
  chart      = "kubeflow-trainer"
  version    = "2.2.0"

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  set {
    name  = "runtimes.defaultEnabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.kubeflow_system]
}

#######################################
# FSx for Lustre
#######################################

# resource "aws_security_group" "fsx_lustre_sg" {
#   name        = "${var.cluster_name}-fsx-lustre-sg"
#   description = "Security group for fsx lustre clients in vpc"
#   vpc_id      = var.vpc_id
#
#   egress {
#     from_port   = 988
#     to_port     = 988
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
#
#   ingress {
#     from_port   = 988
#     to_port     = 988
#     protocol    = "tcp"
#     cidr_blocks = [var.vpc_cidr_block]
#   }
# }
#
# resource "aws_fsx_lustre_file_system" "fs" {
#   file_system_type_version = "2.15"
#
#   storage_capacity = 1200
#   subnet_ids       = [var.private_subnets[0]]
#
#   deployment_type = "SCRATCH_2"
#
#   security_group_ids = [aws_security_group.fsx_lustre_sg.id]
#
#   log_configuration {
#     level = "WARN_ERROR"
#   }
#
#   tags = {
#     Cluster = var.cluster_name
#   }
# }
#
# resource "aws_s3_bucket" "ml_platform" {
#   bucket = "${var.cluster_name}-ml-platform"
# }
#
# resource "aws_fsx_data_repository_association" "this" {
#   file_system_id                   = aws_fsx_lustre_file_system.fs.id
#   data_repository_path             = "s3://${aws_s3_bucket.ml_platform.id}"
#   file_system_path                 = "/${var.cluster_name}-ml-platform"
#   batch_import_meta_data_on_create = true
#
#   s3 {
#     auto_export_policy {
#       events = ["NEW", "CHANGED", "DELETED"]
#     }
#
#     auto_import_policy {
#       events = ["NEW", "CHANGED", "DELETED"]
#     }
#   }
# }
#
# resource "helm_release" "pv_fsx" {
#   chart     = "../charts/pv-fsx"
#   name      = "pv-fsx"
#   version   = "1.1.0"
#   namespace = kubernetes_namespace.kubeflow.metadata[0].name
#
#   set {
#     name  = "namespace"
#     value = kubernetes_namespace.kubeflow.metadata[0].name
#   }
#
#   set {
#     name  = "fs_id"
#     value = aws_fsx_lustre_file_system.fs.id
#   }
#
#   set {
#     name  = "mount_name"
#     value = aws_fsx_lustre_file_system.fs.mount_name
#   }
#
#   set {
#     name  = "dns_name"
#     value = aws_fsx_lustre_file_system.fs.dns_name
#   }
#
#   depends_on = [aws_fsx_data_repository_association.this]
# }

#######################################
# Kubeflow Pipelines
#######################################
resource "helm_release" "kubeflow_pipelines" {
  name      = "kubeflow-pipelines"
  chart     = "../charts/pipelines"
  version   = "1.1.7"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  timeout       = 600
  wait          = true
  wait_for_jobs = true

  values = [
    <<-EOT
      kubeflow:
        namespace: "${kubernetes_namespace.kubeflow.metadata[0].name}"
      ingress:
        namespace: "ingress"
        gateway: "ingress-gateway"
        sa: "istio-ingressgateway"
      minio:
        access_key: "${random_password.minio_access_key.result}"
        secret_key: "${random_password.minio_secret_key.result}"
      profile_namespaces:
      - "${local.admin_profile_namespace}"
    EOT
  ]

  depends_on = [helm_release.istio_ingress]
}

#######################################
# Kubeflow Central Dashboard + OIDC
#######################################

# oauth2-proxy requires cookie_secret to be exactly 16, 24, or 32 raw bytes
# (one of the AES key sizes). 32 random alphanumeric chars = 32 bytes raw.
resource "random_password" "oauth2_proxy_cookie" {
  length  = 32
  special = false
}

resource "helm_release" "oauth2_proxy" {
  name      = "oauth2-proxy"
  chart     = "../charts/oauth2-proxy"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 300

  values = [
    yamlencode({
      namespace      = kubernetes_namespace.kubeflow.metadata[0].name
      dashboard_host = local.dashboard_host
      ingress = {
        namespace = "ingress"
        gateway   = "ingress-gateway"
      }
      oidc = {
        issuer_url    = var.dex_issuer_uri
        client_id     = "kubeflow-oidc-authservice"
        client_secret = var.kubeflow_oidc_client_secret
      }
      upstreams = {
        dex_service = var.dex_internal_url
      }
      cookie_secret = random_password.oauth2_proxy_cookie.result
    })
  ]
}

resource "helm_release" "kubeflow_profiles" {
  name      = "kubeflow-profiles"
  chart     = "../charts/kubeflow-profiles"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      namespace               = kubernetes_namespace.kubeflow.metadata[0].name
      image_tag               = "v2.0.0-rc.1"
      admin_email             = var.admin_email
      admin_profile_namespace = local.admin_profile_namespace
      userid_header           = "X-Forwarded-Email"
    })
  ]

  depends_on = [helm_release.kubeflow_pipelines]
}

resource "helm_release" "kubeflow_dashboard" {
  name      = "kubeflow-dashboard"
  chart     = "../charts/kubeflow-dashboard"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      namespace = kubernetes_namespace.kubeflow.metadata[0].name
      image = {
        repository = "ghcr.io/kubeflow/dashboard/dashboard"
        tag        = "v2.0.0"
      }
      userid_header     = "X-Forwarded-Email"
      registration_flow = "false"
      logout_url        = "/oauth2/sign_out"
    })
  ]

  depends_on = [helm_release.kubeflow_profiles]
}

module "acm_dashboard" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 6.0"

  domain_name       = local.dashboard_host
  zone_id           = var.root_zone_id
  validation_method = "DNS"
}

resource "kubernetes_ingress_v1" "dashboard_ingress" {
  metadata {
    name      = "dashboard-ingress"
    namespace = "ingress"
    annotations = {
      "external-dns.alpha.kubernetes.io/hostname"      = local.dashboard_host
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/healthcheck"
      "alb.ingress.kubernetes.io/success-codes"        = "200"
      "alb.ingress.kubernetes.io/group.name"           = "${var.resource_prefix}-alb"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"         = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({ "Type" : "redirect", "RedirectConfig" : { "Protocol" : "HTTPS", "Port" : "443", "StatusCode" : "HTTP_301" } })
      "alb.ingress.kubernetes.io/inbound-cidrs"        = "0.0.0.0/0"
    }
  }

  spec {
    ingress_class_name = "alb"

    tls {
      hosts = [local.dashboard_host]
    }

    rule {
      host = local.dashboard_host
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
      host = local.dashboard_host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "istio-ingressgateway"
              port { number = 80 }
            }
          }
        }
      }
    }
  }

  wait_for_load_balancer = true
  depends_on             = [module.acm_dashboard, helm_release.kubeflow_dashboard]
}

output "dashboard_url" {
  description = "URL for the Kubeflow Central Dashboard"
  value       = "https://${local.dashboard_host}"
}