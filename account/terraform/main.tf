data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Looked up once here so downstream modules consume the zone id as a (mockable)
# dependency output instead of each running a live lookup that breaks `run-all plan`.
data "aws_route53_zone" "root" {
  name         = var.root_domain
  private_zone = false
}