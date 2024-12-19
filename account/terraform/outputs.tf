output "org" {
  description = "The organization"
  value       = var.org
}

output "region" {
  description = "The target region to deploy infrastructure"
  value       = var.region
}

output "env" {
  description = "The purpose of the environment"
  value       = var.env
}

output "resource_prefix" {
  description = "The prefix for resources"
  value       = "${var.org}-${var.env}"
}

output "available_azs" {
  description = "The zones available to the account"
  value       = data.aws_availability_zones.available.names
}

output "caller_arn" {
  description = "The caller identity"
  value       = data.aws_caller_identity.current.arn
}

output "account_id" {
  description = "The account ID"
  value       = data.aws_caller_identity.current.account_id
}

