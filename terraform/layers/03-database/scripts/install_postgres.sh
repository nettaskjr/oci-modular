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

# Notificar Discord (opcional se a URL estiver presente)
if [ -n "${discord_webhook_url}" ]; then
  curl -H "Content-Type: application/json" \
    -d "{\"embeds\": [{\"title\": \"✅ Database Provisioned\", \"description\": \"PostgreSQL instalado na instância AMD Always Free.\", \"color\": 3066993}]}" \
    "${discord_webhook_url}"
fi
