#!/bin/bash
# OCI User Data Script - MinIO
set -e

# Log de execução para debug
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Função de Notificação Discord
notify_discord() {
  local MESSAGE="$1"
  if [ -n "${discord_webhook_url}" ]; then
    curl -H "Content-Type: application/json" -d "{\"content\": \"$MESSAGE\"}" "${discord_webhook_url}" || true
  fi
}

# Atualizar sistema
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y

# Abrir portas 9000 (API) e 9001 (Console) no firewall interno
if command -v iptables > /dev/null; then
  iptables -I INPUT 1 -p tcp --dport 9000 -j ACCEPT
  iptables -I INPUT 1 -p tcp --dport 9001 -j ACCEPT
  
  if command -v ufw > /dev/null; then
    ufw disable || true
  fi

  if [ -f /sbin/netfilter-persistent ]; then
    netfilter-persistent save || true
  fi
fi

# Baixar e instalar MinIO para AMD64
wget https://dl.min.io/server/minio/release/linux-amd64/minio -O /usr/local/bin/minio
chmod +x /usr/local/bin/minio

# Criar usuário e diretórios
useradd -r minio-user -s /sbin/nologin || true
mkdir -p /mnt/data
chown minio-user:minio-user /mnt/data

# Configurar variáveis de ambiente do MinIO
cat <<EOT > /etc/default/minio
MINIO_ROOT_USER="${minio_root_user}"
MINIO_ROOT_PASSWORD="${minio_root_password}"
MINIO_VOLUMES="/mnt/data"
MINIO_OPTS="--address :9000 --console-address :9001"
EOT

# Criar Systemd Service
cat <<EOT > /etc/systemd/system/minio.service
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOT

# Iniciar MinIO
systemctl daemon-reload
systemctl enable minio
systemctl start minio

# Notificar Discord
notify_discord "☁️ **MinIO Storage UP!**\n- 📂 Console: http://10.0.1.x:9001\n- 🔄 Pronto para uso como S3 interno."
