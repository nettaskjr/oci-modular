#!/bin/bash

discord_webhook_url="https://discordapp.com/api/webhooks/1458215228712943708/c1Ky4zeSQihHm0zRNP9RJ_bGmDt6yGkAeK9pOgwR61ekbsatHO2XEisBEv8xOUrpOLhy"
domain_name="nettask.com.br"

notify_discord() {
  local MESSAGE="$1"
  local separador="-----------------------------------------"
  curl -H "Content-Type: application/json" -d "{\"content\": \"$separador\"}" "${discord_webhook_url}" || true
  if [ -n "${discord_webhook_url}" ]; then
    curl -H "Content-Type: application/json" -d "{\"content\": \"$MESSAGE\"}" "${discord_webhook_url}" || true
  fi
}

notify_discord "⏳ **Cloudflare Tunnel UP!**\n- 🔐 SSH disponível: \`ssh ssh.${domain_name}\`\n- 🔄 Aguardando setup do Kubernetes..."

notify_discord "🚀 **Infra OCI com Persistência Pronta!**\n ☸️ **Kubernetes Status:** OK!\n- 🐳 **Portainer:** https://portainer.${domain_name}\n- 📊 **Grafana:** https://grafana.${domain_name}\n- 🐘 **Postgres & 🗄️ CloudBeaver:** https://db.${domain_name}\n- 📦 **MinIO Console:** https://minio.${domain_name}\n- ☁️ **MinIO S3 API:** https://s3.${domain_name}\n\n✅ Todos os volumes iSCSI (DB 50GB & MinIO 100GB) foram montados com sucesso!"