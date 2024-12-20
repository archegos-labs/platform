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

  version     = "v1.8.0"

  wait          = true
  wait_for_jobs = true

  set {
    name  = "namespace"
    value = kubernetes_namespace.kubeflow.metadata[0].name
  }

  depends_on = [kubernetes_namespace.kubeflow]
}
