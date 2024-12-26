resource "kubernetes_namespace" "kubeflow" {
  metadata {
    labels = {
      control-plane   = "kubeflow"
      istio-injection = "enabled"
    }

    name = "kubeflow"
  }
}

resource "helm_release" "kubeflow_issuer" {
  name        = "kubeflow-issuer"
  description = "A Helm chart to deploy kubeflow-issuer"
  chart       = "../charts/kubeflow-issuer"
  version     = "v1.8.0"

  wait          = true
  wait_for_jobs = true

  depends_on = [kubernetes_namespace.kubeflow]
}

resource "helm_release" "training_operator" {
  name        = "kubeflow-training-operator"
  description = "A Helm chart to deploy kubeflow-trianing-operator"
  namespace   = kubernetes_namespace.kubeflow.metadata[0].name
  chart       = "../charts/training-operator"

  version = "v1.8.0"

  wait          = true
  wait_for_jobs = true

  set {
    name  = "namespace"
    value = kubernetes_namespace.kubeflow.metadata[0].name
  }

  depends_on = [kubernetes_namespace.kubeflow]
}

#######################################
# FSx for Lustre
#######################################

resource "aws_security_group" "fsx_lustre_sg" {
  name = "${var.cluster_name}-fsx-lustre-sg"
  description = "Security group for fsx lustre clients in vpc"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 988
    to_port     = 988
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }
}

resource "aws_fsx_lustre_file_system" "fs" {
  file_system_type_version = "2.15"

  storage_capacity = "1200GiB"
  subnet_ids       = [var.private_subnets[0]]

  deployment_type  = "SCRATCH_2"

  security_group_ids = [aws_security_group.fsx_lustre_sg.id]

  log_configuration {
    level = "WARN_ERROR"
  }

  tags = {
    Cluster = var.cluster_name
  }
}