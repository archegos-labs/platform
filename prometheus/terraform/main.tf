resource "helm_release" "prometheus" {
  name             = "prometheus"
  description      = "Prometheus monitoring stack"
  chart            = "kube-prometheus-stack"
  namespace        = var.prometheus_namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  version          = "v67.3.1"

  wait          = true
  wait_for_jobs = true

  cleanup_on_fail = true
  values = [
    <<EOF
    alertmanager:
      enabled: false
    EOF
  ]
}