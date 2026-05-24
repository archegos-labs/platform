resource "kubernetes_namespace" "kubeflow" {
  metadata {
    labels = {
      control-plane   = "kubeflow"
      istio-injection = "enabled"
      # No PSS enforcement: Istio init containers require NET_ADMIN/NET_RAW
      # which are blocked by both baseline and restricted.
    }

    name = "kubeflow"
  }
}

resource "kubernetes_namespace" "kubeflow_system" {
  metadata {
    labels = {
      control-plane = "kubeflow"
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
  version   = "1.0.2"
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
    EOT
  ]

  depends_on = [helm_release.istio_ingress]
}