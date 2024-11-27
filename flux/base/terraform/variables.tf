variable "cluster_name" {
  description = "The name of the EKS cluster"
  type = string
}

variable "cluster_endpoint" {
  description = "The name of the EKS cluster"
  type = string
}

variable "cluster_certificate_authority_data" {
  description = "The certificate authority data"
  type = string
}

variable "github_org" {
  description = "The GitHub organization"
  type = string
}

variable "github_repository" {
  description = "The GitHub repository"
  type = string
}

variable "github_pat" {
  description = "The GitHub personal access token"
  type = string
}