#!/bin/bash

domain_name="nettask.com.br"

notify_webhook() {
  local MESSAGE="$1"
  local separador="-----------------------------------------"
  curl -H "Content-Type: application/json" -d "{\"content\": \"$separador\"}" "${webhook_url}" || true
  if [ -n "${webhook_url}" ]; then
    curl -H "Content-Type: application/json" -d "{\"content\": \"$MESSAGE\"}" "${webhook_url}" || true
  fi
}

notify_webhook "⏳ **Cloudflare Tunnel UP!**\n- 🔐 SSH disponível: \`ssh ssh.${domain_name}\`\n- 🔄 Aguardando setup do Kubernetes..."

notify_webhook "🚀 **Infra OCI com Persistência Pronta!**\n ☸️ **Kubernetes Status:** OK!\n- 🐳 **Portainer:** https://portainer.${domain_name}\n- 📊 **Grafana:** https://grafana.${domain_name}\n- 🐘 **Postgres & 🗄️ CloudBeaver:** https://db.${domain_name}\n- 📦 **MinIO Console:** https://minio.${domain_name}\n- ☁️ **MinIO S3 API:** https://s3.${domain_name}\n\n✅ Todos os volumes iSCSI (DB 50GB & MinIO 100GB) foram montados com sucesso!"

notify_webhook "🚀 **Infra OCI Base Pronta!**\n ☸️ **Status:** Servidor configurado e repositórios clonados.\n\n⚠️ **Nota:** A configuração de aplicações (bancos n8n, etc) deve ser feita via scripts do repositório do cliente."
