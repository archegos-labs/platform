include "root" {
  path = find_in_parent_folders()
  expose = true
}

locals {
  org = include.root.locals.org
  region = include.root.locals.region
  env = include.root.locals.env
}

terraform {
  source = ".//terraform"
}

inputs = {
    org = local.org
    env = local.env
    region = local.region
}