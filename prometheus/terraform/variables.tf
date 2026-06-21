variable "resource_prefix" {
  description = "The prefix for resources"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "root_domain" {
  description = "Root DNS zone used for admin-facing hostnames. Provided by the account module."
  type        = string
}

variable "root_zone_id" {
  description = "Route 53 hosted zone ID for root_domain, looked up in the account module so this module makes no live zone lookup at plan time."
  type        = string
}

variable "prometheus_namespace" {
  description = "Prometheus name space"
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

variable "admin_email" {
  description = "Email of the platform admin user, used to grant the GrafanaAdmin role via OIDC role mapping."
  type        = string
}

variable "dex_issuer_uri" {
  description = "Dex OIDC issuer URI. Provided by the auth/dex module."
  type        = string
}

variable "grafana_oidc_client_secret" {
  description = "OIDC client secret for the 'grafana' client, registered with Dex. Provided by the auth/dex module."
  type        = string
  sensitive   = true
}
