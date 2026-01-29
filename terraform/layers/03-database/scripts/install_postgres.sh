#!/bin/bash
# OCI User Data Script - PostgresSQL
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
  iptables -I INPUT 1 -p tcp --dport 5432 -j ACCEPT # PostgreSQL
  iptables -I INPUT 1 -p tcp --dport 9100 -j ACCEPT # Node Exporter
  
  # Desativar ufw se estiver ativo
  if command -v ufw > /dev/null; then
    ufw disable || true
  fi

  # Salvar as regras
  if [ -f /sbin/netfilter-persistent ]; then
    netfilter-persistent save || true
  fi
fi

# Instalar Node Exporter para monitoramento
apt-get install -y prometheus-node-exporter
systemctl enable prometheus-node-exporter
systemctl start prometheus-node-exporter

# Instalar PostgreSQL
apt-get install -y postgresql postgresql-contrib

# Configurar PostgreSQL para aceitar conexões externas (opcional, vamos controlar no firewall da OCI também)
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf

# Permitir conexões apenas da rede interna da VCN (10.0.0.0/16)
echo "host    all             all             10.0.0.0/16            md5" >> /etc/postgresql/*/main/pg_hba.conf

# Criar usuário e banco de dados inicial
sudo -u postgres psql -c "CREATE USER ${db_user} WITH PASSWORD '${db_password}';"
sudo -u postgres psql -c "CREATE DATABASE ${db_name} OWNER ${db_user};"

# Reiniciar serviço
systemctl restart postgresql
systemctl enable postgresql

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
- job_name: journal
  journal:
    max_age: 12h
    labels:
      job: systemd-journal
      host: database-postgres
  relabel_configs:
    - source_labels: ['__journal__systemd_unit']
      target_label: 'unit'
    # Regra mágica: Se a unidade for o postgresql, mude o label 'job' para 'postgresql-logs'
    - source_labels: ['unit']
      regex: 'postgresql.*'
      target_label: 'job'
      replacement: 'postgresql-logs'

- job_name: database-system-files
  static_configs:
  - targets:
      - localhost
    labels:
      job: system-logs
      host: database-postgres
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
systemctl restart promtail

# Notificar Discord sobre Database UP
notify_discord "- 🛢️ **Database: PostgreSQL UP! (Logs OK)**"
