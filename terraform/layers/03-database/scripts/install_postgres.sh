#!/bin/bash
# OCI User Data Script - PostgresSQL
set -e

# Log de execução para debug
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Função de Notificação Discord
notify_discord() {
  local MESSAGE="$1"
  if [ -n "${discord_webhook_url}" ]; then
    # Usamos o printf para garantir que o \n seja interpretado corretamente no JSON
    local JSON_PAYLOAD=$(printf '{"content": "%b"}' "$MESSAGE")
    curl -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "${discord_webhook_url}" || true
  fi
}

# Atualizar sistema
export DEBIAN_FRONTEND=noninteractive
apt-get update && apt-get upgrade -y

# Abrir porta 5432 no firewall interno do Ubuntu (OCI padrão bloqueia)
if command -v iptables > /dev/null; then
  iptables -I INPUT 6 -p tcp --dport 5432 -j ACCEPT
  # Tentar salvar as regras se o pacote estiver instalado
  if [ -f /sbin/netfilter-persistent ]; then
    netfilter-persistent save
  fi
fi

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
notify_discord "🛢️ **Database: PostgreSQL UP!**\n- 🔄 Aguardando setup do Kubernetes..."
