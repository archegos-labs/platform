locals {
  organization = get_env("ORG_NAME")
  region       = "us-east-1"
  env          = "dev"
  root_domain  = get_env("ROOT_DOMAIN")
  admin_email  = get_env("ADMIN_EMAIL")
}