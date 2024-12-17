resource "kubernetes_namespace" "kubeflow" {
  metadata {
    labels = {
      control-plane   = "kubeflow"
      istio-injection = "enabled"
    }

    name = "kubeflow"
  }
}

module "kubeflow_issuer" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "1.1.1"

  name             = "kubeflow-issuer"
  description      = "A Helm chart to deploy kubeflow-issuer"
  chart            = "../charts/kubeflow-issuer"
  chart_version    = "v1.6.1"

  wait                       = true
  wait_for_jobs              = true

  depends_on    = [kubernetes_namespace.kubeflow]
}