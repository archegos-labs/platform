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

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint. Provided by the eks/cluster module."
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA certificate. Provided by the eks/cluster module."
  type        = string
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

variable "root_zone_id" {
  description = "Route 53 hosted zone ID for root_domain, looked up in the account module so this module makes no live zone lookup at plan time."
  type        = string
}

