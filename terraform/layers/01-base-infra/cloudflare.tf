resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "auto_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "oci-ubuntu-tunnel-${var.instance_display_name}"
  secret     = base64sha256(random_password.tunnel_secret.result)
}

resource "cloudflare_record" "cname_wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.auto_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "cname_root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.auto_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
