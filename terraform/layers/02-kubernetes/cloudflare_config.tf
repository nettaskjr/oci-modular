resource "cloudflare_zero_trust_tunnel_cloudflared_config" "auto_tunnel_config" {
  tunnel_id  = data.terraform_remote_state.base.outputs.tunnel_id
  account_id = data.terraform_remote_state.base.outputs.cloudflare_account_id

  config {
    # Regra para ACESSO SSH
    ingress_rule {
      hostname = "ssh.${var.domain_name}"
      service  = "ssh://localhost:22"
    }

    # Regra para Console MinIO
    ingress_rule {
      hostname = "minio.${var.domain_name}"
      service  = "http://${data.terraform_remote_state.storage.outputs.minio_internal_ip}:9001"
    }

    # Regra para CloudBeaver (Database GUI)
    ingress_rule {
      hostname = "db.${var.domain_name}"
      service  = "http://${data.terraform_remote_state.database.outputs.db_internal_ip}:8978"
    }

    # Regra genérica para HTTP/HTTPS (Web)
    ingress_rule {
      service = "http://localhost:80"
    }
  }
}
