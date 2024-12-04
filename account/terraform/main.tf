data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "utils" {
  source  = "cloudposse/utils/aws"
  version     = "1.4.0"
}

locals {
  code_maps = module.utils.region_az_alt_code_maps
}
