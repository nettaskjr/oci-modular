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

# Notificar Discord sobre Database UP
notify_discord "- 🛢️ **Database: PostgreSQL UP!**\n"
