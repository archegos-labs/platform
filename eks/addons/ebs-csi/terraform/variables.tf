variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "service_account" {
  description = "The name of the serivce account to use for the controller"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API endpoint (for the kubernetes provider)"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster CA certificate (for the kubernetes provider)"
  type        = string
}

