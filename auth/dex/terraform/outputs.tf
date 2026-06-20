output "dex_issuer_uri" {
  description = "Public OIDC issuer URI for Dex (used by OIDC clients to discover endpoints)"
  value       = local.issuer_uri
}

output "dex_internal_url" {
  description = "In-cluster Dex address (host:port) for server-to-server calls like oauth2-proxy redeem/jwks"
  value       = "${local.release_name}.${local.namespace}.svc.cluster.local:5556"
}

output "oidc_client_secrets" {
  description = "Map of OIDC client_id -> client_secret for each registered static client"
  value       = { for id, r in random_password.oidc_client_secret : id => r.result }
  sensitive   = true
}

output "dex_admin_password" {
  description = "Initial password for the Dex admin static user. Retrieve with: terragrunt output -raw dex_admin_password"
  value       = random_password.dex_admin.result
  sensitive   = true
}