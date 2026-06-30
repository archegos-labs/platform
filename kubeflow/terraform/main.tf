locals {
  dashboard_host = "dashboard.admin.${var.root_domain}"
  # Single source of truth for provisioned profiles. Drives the kubeflow-profiles release
  # (one Profile CR + pre-created namespace + waypoint Gateway + ns-owner-access-waypoint
  # policy per entry) AND the pipelines release (profile_namespaces, which scopes the
  # ml-pipeline / minio / metadata-grpc AuthorizationPolicies to each namespace's
  # default-editor — ztunnel needs exact principals, no wildcards). Add a profile by
  # appending { namespace, owner } here (platform-lyl).
  #
  # `contributors` (optional) lists additional authenticated emails granted L7 access to
  # the namespace's workloads at the waypoint. Dashboard-added contributors get a kfam
  # RoleBinding + a namespace-wide AuthorizationPolicy, but that policy has no waypoint
  # targetRef so ztunnel drops its HTTP rule — leaving the contributor without mesh access
  # (notebooks/registry 403). Listing them here renders their email into
  # ns-owner-access-waypoint so the waypoint enforces it. RBAC (kubeflow-edit RoleBinding)
  # still comes from the dashboard add-contributor flow.
  profiles = [
    { namespace = "kubeflow-admin", owner = var.admin_email, contributors = ["padpatil@uw.edu"] },
  ]
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

# Artifact-store admin credential. Despite the minio_* names (kept to avoid churning
# the helm values/secret keys), these now seed the SeaweedFS admin user: the chart's
# mlpipeline-minio-artifact secret is consumed by the SeaweedFS postStart bootstrap
# (s3.configure kubeflow-admin) and by the profile-controller's IAM client, which
# mints per-namespace credentials. Not vestigial — required by the SeaweedFS backend.
resource "random_password" "minio_access_key" {
  length  = 16
  special = false
}

resource "random_password" "minio_secret_key" {
  length  = 32
  special = false
}

# MySQL root password for the in-cluster KFP DB (replaces the upstream empty-password
# default). The chart wires it into mysql-secret + the mysql container MYSQL_ROOT_PASSWORD.
resource "random_password" "mysql_root_password" {
  length  = 32
  special = false
}

# MySQL root password for the in-cluster Hub (Model Registry) datastore. Replaces the
# upstream root/test default; wired into model-registry-db-secrets MYSQL_ROOT_PASSWORD.
resource "random_password" "hub_mysql_password" {
  length  = 32
  special = false
}

# Postgres password for the Hub model-catalog datastore.
resource "random_password" "hub_catalog_pg_password" {
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
  version    = "2.2.1"

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # runtimes.defaultEnabled is intentionally false: the ClusterTrainingRuntime
  # blueprints are applied by the separate kubeflow_trainer_runtimes release below.
  # The operator's validating webhook serves a self-rotated cert whose serving-side
  # reload lags the caBundle patch by ~20s; bundling the runtime CRs here makes their
  # CREATE/UPDATE patches race that window and fail every upgrade with x509
  # "unknown authority". Keeping them out means this release never patches a
  # webhook-validated resource.
  set {
    name  = "runtimes.defaultEnabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.kubeflow_system]
}

# ClusterTrainingRuntime blueprints, decoupled from the operator release above so the
# operator's webhook cert rotation can't fail operator upgrades. See the chart's
# Chart.yaml for the full rationale. This release rarely changes, so it rarely patches
# the webhook; the operator release (which triggers the cert refresh) no longer carries
# any webhook-validated resources.
#
# On a cluster where the runtimes are still bundled in the operator release, a one-time
# migration must run BEFORE this is applied, or the operator upgrade deletes the CRs and
# this release recreates them through the racing webhook. Runbook:
# kubeflow/docs/trainer-runtimes-migration.md
resource "helm_release" "kubeflow_trainer_runtimes" {
  name      = "kubeflow-trainer-runtimes"
  namespace = kubernetes_namespace.kubeflow_system.metadata[0].name
  chart     = "../charts/kubeflow-trainer-runtimes"

  wait          = true
  wait_for_jobs = true

  depends_on = [helm_release.kubeflow_trainer]
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
  version   = "1.3.0"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  timeout       = 600
  wait          = true
  wait_for_jobs = true

  values = [
    yamlencode({
      kubeflow = {
        namespace = kubernetes_namespace.kubeflow.metadata[0].name
      }
      ingress = {
        namespace = "ingress"
        gateway   = "ingress-gateway"
        sa        = "istio-ingressgateway"
      }
      minio = {
        access_key = random_password.minio_access_key.result
        secret_key = random_password.minio_secret_key.result
      }
      mysql = {
        root_password = random_password.mysql_root_password.result
      }
      # Scopes the ml-pipeline / minio / metadata-grpc AuthorizationPolicies to each
      # profile namespace's default-editor (driven from the same local.profiles list as
      # the kubeflow-profiles release — single source of truth, platform-lyl).
      profile_namespaces = [for p in local.profiles : p.namespace]
    })
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
      # Trust only the VPC CIDR (the in-cluster ingress gateway, whose pod IP is the peer under
      # ambient) plus loopback (the local proxy hop if a sidecar is ever injected) to set
      # X-Forwarded-* headers, instead of the trust-all default. Layers on the
      # ingress-gateway-only AuthorizationPolicy.
      trusted_proxy_ips = [var.vpc_cidr_block, "127.0.0.0/8"]
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
      namespace     = kubernetes_namespace.kubeflow.metadata[0].name
      image_tag     = "v2.0.0"
      admin_email   = var.admin_email
      profiles      = local.profiles
      userid_header = "x-forwarded-email"
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
      userid_header     = "x-forwarded-email"
      registration_flow = "false"
      logout_url        = "/oauth2/sign_out"
    })
  ]

  depends_on = [helm_release.kubeflow_profiles]
}

#######################################
# Kubeflow Notebooks (notebook-controller + Jupyter Web App)
#######################################
resource "helm_release" "kubeflow_notebooks" {
  name      = "kubeflow-notebooks"
  chart     = "../charts/kubeflow-notebooks"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      namespace     = kubernetes_namespace.kubeflow.metadata[0].name
      userid_header = "x-forwarded-email"
      ingress = {
        namespace = "ingress"
      }
    })
  ]

  # Profile namespaces + default-editor + per-profile waypoints (which enforce the
  # owner authz that per-notebook traffic traverses) must exist first.
  depends_on = [helm_release.kubeflow_profiles]
}

#######################################
# Kubeflow Hub (Model Registry + Model Catalog)
#######################################
resource "helm_release" "kubeflow_hub" {
  name      = "kubeflow-hub"
  chart     = "../charts/kubeflow-hub"
  namespace = kubernetes_namespace.kubeflow.metadata[0].name

  wait          = true
  wait_for_jobs = true
  timeout       = 600

  values = [
    yamlencode({
      namespace     = kubernetes_namespace.kubeflow.metadata[0].name
      userid_header = "x-forwarded-email"
      # Same source of truth as the other releases: profile workloads (default-editor) may
      # reach the registry server in-cluster via the SDK.
      profile_namespaces = [for p in local.profiles : p.namespace]
      registry = {
        db = {
          password = random_password.hub_mysql_password.result
        }
      }
      catalog = {
        postgres = {
          password = random_password.hub_catalog_pg_password.result
        }
      }
      ingress = {
        namespace = "ingress"
      }
    })
  ]

  # The registry server + datastore are deployed per profile namespace, so those namespaces
  # (created by the profiles release) must exist first. kubeflow_profiles transitively depends
  # on istio_ingress (the shared gateway the Hub UI listener selects).
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