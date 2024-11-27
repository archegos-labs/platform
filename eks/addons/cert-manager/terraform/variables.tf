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

variable "service_account" {
  description = "The name of the serivce account to use for the controller"
  type = string
}