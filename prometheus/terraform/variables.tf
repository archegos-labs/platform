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

variable "prometheus_namespace" {
  description = "Prometheus name space"
  type        = string
  default     = "monitoring"
}

variable "kube_data_auth_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
    If `true`, use an `aws_eks_cluster_auth` data source to authenticate to the EKS cluster.
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
