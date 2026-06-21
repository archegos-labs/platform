variable "vpc_id" {
  description = "The Id of the VPC"
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR block allocated to the VPC"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "private_subnets" {
  description = "The private subnets of the EKS cluster"
  type        = list(string)
}

variable "resource_prefix" {
  description = "The prefix for resources"
  type        = string

  validation {
    condition     = length(var.resource_prefix) > 0
    error_message = "resource_prefix must not be empty (used as the shared ALB group name)."
  }
}

variable "root_domain" {
  description = "Root DNS zone used for all admin-facing hostnames. Provided by the account module."
  type        = string
}

variable "root_zone_id" {
  description = "Route 53 hosted zone ID for root_domain, looked up in the account module so this module makes no live zone lookup at plan time."
  type        = string
}

variable "admin_email" {
  description = "Email of the initial Kubeflow admin (Dex static user and Profile owner). Provided by the account module."
  type        = string
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

variable "dex_issuer_uri" {
  description = "Dex OIDC issuer URI. Provided by the auth/dex module."
  type        = string
}

variable "dex_internal_url" {
  description = "In-cluster Dex address (host:port) used by oauth2-proxy for server-to-server token/JWKS calls. Provided by the auth/dex module."
  type        = string
}

variable "kubeflow_oidc_client_secret" {
  description = "OIDC client secret for the kubeflow-oidc-authservice client, registered with Dex. Provided by the auth/dex module."
  type        = string
  sensitive   = true
}
