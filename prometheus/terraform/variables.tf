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

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint. Provided by the eks/cluster module."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA certificate. Provided by the eks/cluster module."
  type        = string
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
