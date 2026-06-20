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

variable "admin_email" {
  description = "Email of the initial Kubeflow admin (Dex static user and Profile owner). Provided by the account module."
  type        = string
}

variable "kube_data_auth_enabled" {
  type        = bool
  default     = false
  description = <<-EOT
    If `true`, use an `aws_eks_cluster_auth` data source to authenticate to the EKS cluster.
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
