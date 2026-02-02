resource "cloudflare_zero_trust_tunnel_cloudflared_config" "auto_tunnel_config" {
  tunnel_id  = data.terraform_remote_state.base.outputs.tunnel_id
  account_id = data.terraform_remote_state.base.outputs.cloudflare_account_id

  config {
    # Regra para ACESSO SSH
    ingress_rule {
      hostname = "ssh.${var.domain_name}"
      service  = "ssh://localhost:22"
    }

    # Regra genérica para HTTP/HTTPS (Web)
    ingress_rule {
      service = "http://localhost:80"
    }
  }
}
