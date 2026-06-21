variable "resource_prefix" {
  description = "The name of the organization"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "istio_namespace" {
  description = "Istio ingress namespace"
  type        = string
  default     = "istio-system"
}

variable "prometheus_namespace" {
  description = "Prometheus namespace"
  type        = string
  default     = "monitoring"
}

variable "kube_data_auth_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
    If `true`, authenticate to the EKS cluster via the `aws_eks_cluster` data source
    (endpoint/CA) plus an `aws eks get-token` exec credential. If `false`, fall back to
    the local kubeconfig context (the `make plan-all` path).
    EOT
  nullable    = false
}

variable "kiali_oidc_client_secret" {
  description = "OIDC client secret for Kiali, registered with Dex"
  type        = string
  sensitive   = true
}

variable "dex_issuer_uri" {
  description = "Dex OIDC issuer URI"
  type        = string
}

variable "root_domain" {
  description = "Root DNS zone for admin-facing hostnames (e.g. kiali/grafana). Provided by the account module."
  type        = string
}

