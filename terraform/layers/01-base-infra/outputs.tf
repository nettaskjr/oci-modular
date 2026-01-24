output "public_subnet_id" {
  value = oci_core_subnet.public_subnet.id
}

output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.auto_tunnel.id
}

output "tunnel_token" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.auto_tunnel.tunnel_token
  sensitive = true
}

output "cloudflare_account_id" {
  value = var.cloudflare_account_id
}

output "vcn_id" {
  value = oci_core_vcn.main_vcn.id
}
