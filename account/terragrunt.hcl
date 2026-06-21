include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  org         = include.root.locals.org
  region      = include.root.locals.region
  env         = include.root.locals.env
  root_domain = include.root.locals.root_domain
  admin_email = include.root.locals.admin_email
}

terraform {
  source = ".//terraform"
}

inputs = {
  org         = local.org
  env         = local.env
  region      = local.region
  root_domain = local.root_domain
  admin_email = local.admin_email
}