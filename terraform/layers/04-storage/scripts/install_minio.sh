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

# Abrir portas no firewall interno do Ubuntu
if command -v iptables > /dev/null; then
  iptables -I INPUT 1 -p tcp --dport 9000 -j ACCEPT # MinIO API
  iptables -I INPUT 1 -p tcp --dport 9001 -j ACCEPT # MinIO Console
  iptables -I INPUT 1 -p tcp --dport 9100 -j ACCEPT # Node Exporter
  
  if command -v ufw > /dev/null; then
    ufw disable || true
  fi

  if [ -f /sbin/netfilter-persistent ]; then
    netfilter-persistent save || true
  fi
fi

# Instalar Node Exporter para monitoramento
apt-get install -y prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

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

# Instalar Promtail para logs
PROMTAIL_VERSION="2.9.2"
curl -Lo promtail.zip "https://github.com/grafana/loki/releases/download/v$${PROMTAIL_VERSION}/promtail-linux-amd64.zip"
apt-get install -y unzip
unzip promtail.zip
mv promtail-linux-amd64 /usr/local/bin/promtail
chmod +x /usr/local/bin/promtail

# Criar configuração do Promtail
mkdir -p /etc/promtail
cat <<EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://${k8s_dns_name}/loki/api/v1/push

scrape_configs:
- job_name: storage-logs
  static_configs:
  - targets:
      - localhost
    labels:
      job: system-logs
      host: storage-minio
      __path__: /var/log/*.log
EOF

# Criar serviço Systemd para o Promtail
cat <<EOF > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail agent
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable promtail
systemctl start promtail

# Notificar Discord sobre Storage UP
notify_discord "- ☁️ **Storage: MinIO UP! (Logs OK)**"
