variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix used for the shared ALB group name"
  type        = string

  validation {
    condition     = length(var.resource_prefix) > 0
    error_message = "resource_prefix must not be empty (used as the shared ALB group name)."
  }
}

variable "root_domain" {
  description = "Root DNS zone used to compute the Dex hostname (dex.admin.<root_domain>)"
  type        = string
}

variable "admin_email" {
  description = "Email of the initial Dex admin (static password user)"
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

variable "oidc_clients" {
  description = "Static OIDC clients to register with Dex. Each entry's secret is generated here and exposed via the oidc_client_secrets output."
  type = list(object({
    id           = string
    name         = string
    redirect_uri = string
  }))
}