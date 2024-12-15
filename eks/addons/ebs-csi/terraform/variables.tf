variable "cluster_name" {
  description = "The name of the EKS cluster"
  type = string
}

variable "cluster_version" {
  description = "The name of the EKS cluster"
  type = string
}

variable "service_account" {
  description = "The name of the serivce account to use for the controller"
  type = string
}
