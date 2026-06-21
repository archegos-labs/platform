variable "org" {
  description = "The organization"
  type        = string
}

variable "region" {
  description = "The target region to deploy infrastructure"
  type        = string
}

variable "env" {
  description = "The purpose of the environment"
  type        = string
}

variable "root_domain" {
  description = "Root DNS zone for all admin-facing hostnames in this deployment."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)+$", var.root_domain))
    error_message = "root_domain must be a valid DNS name."
  }
}

variable "admin_email" {
  description = "Email of the platform admin (Dex static user, Profile owner, etc.)."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.admin_email))
    error_message = "admin_email must be a valid email address."
  }
}

