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

variable "tf_deployer_aws_access_key" {
  description = "The AWS access key for the Terraform deployment user"
  type = string
  sensitive = true
}

variable "tf_deployer_aws_secret_key" {
  description = "The AWS secret key for the Terraform deployment user"
  type = string
  sensitive = true
}