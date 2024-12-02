locals {
  deployment  = get_env("DEPLOYMENT")
  deploy_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/deployments/${local.deployment}.hcl")

  org    = local.deploy_vars.locals.organization
  region = local.deploy_vars.locals.region
  env    = local.deploy_vars.locals.env
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket  = "terraform-state-${local.org}-${local.region}"
    key     = "${local.env}/platform/${path_relative_to_include()}/terraform.tfstate"
    encrypt = false
    region  = "${local.region}"
    profile = "default"
  }
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<EOF
    terraform {
      required_version = ">= 1.0"

      required_providers {
        aws = {
          source = "hashicorp/aws"
          version = ">= 5.78.0"
        }
        flux = {
          source  = "fluxcd/flux"
          version = ">= 1.4"
        }
        github = {
          source  = "integrations/github"
          version = ">= 6.3"
        }
        tls = {
          source  = "hashicorp/tls"
          version = ">= 4.0"
        }
      }
    }
  EOF
}

generate "aws-provider" {
  path      = "aws_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = {
            Organization = "${title(local.org)}"
            Environment = "${title(local.env)}"
            ManagedBy = "Terraform"
            Deployment = "Terragrunt"
        }
      }
    }
  EOF
}