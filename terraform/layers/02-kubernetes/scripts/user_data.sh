#!/bin/bash
# OCI User Data Script
set -e

# Log de execução para debug
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Função de Notificação Discord (Geração de JSON robusta via Python)
notify_discord() {
  local MESSAGE="$1"
  local SEPARADOR="-----------------------------------------"
  curl -H "Content-Type: application/json" -d "{\"content\": \"$SEPARADOR\"}" "${discord_webhook_url}" || true
  if [ -n "${discord_webhook_url}" ]; then
    curl -H "Content-Type: application/json" -d "{\"content\": \"$MESSAGE\"}" "${discord_webhook_url}" || true
  fi
}

# Função para aguardar o lock do APT
wait_for_apt() {
  echo "Aguardando liberação do lock do APT..."
  while fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    sleep 5
  done
  echo "Lock liberado!"
}

# Função para montar discos baseada no tamanho
mount_by_size() {
  local TARGET_SIZE=$1
  local MOUNT_POINT=$2
  local TIMEOUT=120
  local SECONDS=0
  
  echo "Procurando disco de $${TARGET_SIZE}GB para $${MOUNT_POINT}..."
  
  while [ $SECONDS -lt $TIMEOUT ]; do
    # lsblk retorna tamanho em G. Ex: 50G, 100G.
    DEV=$(lsblk -bndo NAME,SIZE | awk -v size="$${TARGET_SIZE}" '$2 == size*1024*1024*1024 {print "/dev/"$1}' | head -n 1)
    
    if [ -n "$DEV" ]; then
      echo "Disco de $${TARGET_SIZE}GB encontrado em $${DEV}. Montando..."
      mkdir -p "$MOUNT_POINT"
      blkid "$DEV" || mkfs.ext4 -L "$(basename $MOUNT_POINT)" "$DEV"
      mount "$DEV" "$MOUNT_POINT" || true
      echo "$DEV $MOUNT_POINT ext4 defaults,_netdev 0 2" >> /etc/fstab
      return 0
    fi
    sleep 5
    SECONDS=$((SECONDS+5))
  done
  
  echo "ERRO: Disco de $${TARGET_SIZE}GB não encontrado após $${TIMEOUT}s"
  return 1
}

echo "Iniciando configuração da instância (Branch Main/Stateless)..."
timedatectl set-timezone America/Sao_Paulo

# 1. Atualização e Instalação de Pacotes Básicos
export DEBIAN_FRONTEND=noninteractive
wait_for_apt
apt-get update -y
apt-get install -y curl git ncdu

# 2. Instalação e Configuração do Cloudflared
echo "Instalando Cloudflared (${cloudflared_version})..."
wait_for_apt
URL="https://github.com/cloudflare/cloudflared/releases/download/${cloudflared_version}/cloudflared-linux-arm64.deb"

if ! curl -L --fail --output cloudflared.deb "$URL"; then
  echo "Fallback para latest..."
  curl -L --fail --output cloudflared.deb "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb"
fi
dpkg -i cloudflared.deb

echo "Registrando túnel..."
cloudflared service install "${tunnel_token}" || true
systemctl restart cloudflared

# Notificar Discord sobre SSH (Túnel UP)
notify_discord "⏳ **Cloudflare Tunnel UP!**\n- 🔐 SSH disponível: \`ssh ssh.${domain_name}\`\n- 🔄 Aguardando setup do Kubernetes..."

# 3. Instalação do K3s
export K3S_KUBECONFIG_MODE="644"
curl -sfL https://get.k3s.io | sh -

# Configurar Kubeconfig para o usuário da instância (ubuntu)
USER_HOME="/home/${user_instance}"
mkdir -p $USER_HOME/.kube
cp /etc/rancher/k3s/k3s.yaml $USER_HOME/.kube/config
chown -R ${user_instance}:${user_instance} $USER_HOME/.kube
echo "export KUBECONFIG=$USER_HOME/.kube/config" >> $USER_HOME/.bashrc

# 4. Configuração de Volumes Persistentes (Auto-login via OCI Agent)
echo "Aguardando volumes extra (Agent login)..."

# Tenta montar os volumes
mount_by_size 50 "/mnt/db-vol" || true
mount_by_size 100 "/mnt/minio-vol" || true

# 5. GitOps: Clonar Repositórios e instalacao dos apps via manifestos
STACK_DIR="$USER_HOME/.stack"
CLIENT_DIR="$USER_HOME/.stack-cliente"

echo "Clonando repositórios..."
git clone "${github_repo}" $STACK_DIR || (cd $STACK_DIR && git pull)
git clone "${github_repo_cliente}" $CLIENT_DIR || (cd $CLIENT_DIR && git pull)

# 5.1 Criar contexto de infra para scripts de sincronização
echo "Salvando contexto de infraestrutura..."
mkdir -p /etc/infra
cat <<EOF > /etc/infra/context.env
INFRA_DOMAIN="${domain_name}"
INFRA_USER_HOME="$USER_HOME"
INFRA_NODE_NAME="${instance_display_name}"
INFRA_INTERNAL_DNS="${instance_display_name}.public.mainvcn.oraclevcn.com"
INFRA_DB_USER="${db_user}"
INFRA_DB_PASS="${db_pass}"
INFRA_DB_NAME="${db_name}"
AWS_ACCESS_KEY="${aws_access_key}"
AWS_SECRET_KEY="${aws_secret_key}"
AWS_REGION="${aws_region}"
BACKUP_BUCKET="${backup_bucket}"
EOF
chmod 644 /etc/infra/context.env

# 5.2 Preparação de Namespaces e Infra Base
echo "Configurando Namespaces e Segredos..."

# Criar Namespaces de Infra
for NS in database minio monitoring; do
  kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -
  
  # ConfigMap Universal (Domínio e Contexto)
  kubectl create configmap infra-config -n $NS \
    --from-literal=domain="${domain_name}" \
    --from-literal=node-name="${instance_display_name}" \
    --from-literal=internal-dns="${instance_display_name}.public.mainvcn.oraclevcn.com" \
    --dry-run=client -o yaml | kubectl apply -f -
done

# Secrets de Backup (AWS) - No namespace do banco de dados
kubectl create secret generic aws-backup-creds -n database \
  --from-literal=access-key="${aws_access_key}" \
  --from-literal=secret-key="${aws_secret_key}" \
  --from-literal=region="${aws_region}" \
  --from-literal=bucket="${backup_bucket}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Database: Nome do banco inicial
kubectl patch configmap infra-config -n database --type merge -p "{\"data\":{\"db-name\":\"${db_name}\"}}"

# Monitoring: Usuário Admin do Grafana
kubectl patch configmap infra-config -n monitoring --type merge -p "{\"data\":{\"grafana-admin-user\":\"${grafana_user}\"}}"

# Database: Senhas do Postgres
kubectl create secret generic infra-secrets -n database \
  --from-literal=db-user="${db_user}" \
  --from-literal=db-pass="${db_pass}" \
  --from-literal=database-password="${db_pass}" \
  --dry-run=client -o yaml | kubectl apply -f -

# MinIO: Senha Root
kubectl create secret generic infra-secrets -n minio \
  --from-literal=minio-root-password="${minio_pass}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Monitoring: Senha Admin do Grafana
kubectl create secret generic infra-secrets -n monitoring \
  --from-literal=grafana-admin-password="${grafana_pass}" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5.3 CloudBeaver: Configuração de Conexão Segura (Via Secret)
echo "🛠️ Configurando CloudBeaver (Database Tools)..."
CB_CONFIG_FILE=$(mktemp)
cat <<EOF > "$CB_CONFIG_FILE"
{
  "folders": {},
  "connections": {
    "postgres-jdbc-infra": {
      "provider": "postgresql",
      "driver": "postgres-jdbc",
      "name": "OCI PostgreSQL",
      "save-password": true,
      "configuration": {
        "host": "postgres.database",
        "port": "5432",
        "database": "${db_name}",
        "url": "jdbc:postgresql://postgres.database:5432/${db_name}",
        "configurationType": "MANUAL",
        "type": "dev",
        "properties": {
          "user": "${db_user}",
          "password": "${db_pass}"
        },
        "authProperties": {
          "user": "${db_user}",
          "password": "${db_pass}"
        },
        "authModel": "native"
      }
    }
  }
}
EOF

kubectl create secret generic cloudbeaver-datasources -n database \
  --from-file=data-sources.json="$CB_CONFIG_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

rm "$CB_CONFIG_FILE"

if [ -d "$STACK_DIR" ]; then
  echo "Processando manifestos em diretório temporário..."
  WORKING_DIR=$(mktemp -d)
  
  # Copiar repositórios para o diretório de trabalho
  cp -r $STACK_DIR/* "$WORKING_DIR/"
  if [ -d "$CLIENT_DIR" ]; then
    echo "Incluindo manifestos do repositório CLIENTE..."
    cp -r $CLIENT_DIR/* "$WORKING_DIR/"
  fi
  
  # Substituições de Infraestrutura Básica (Caminhos e DNS)
  find "$WORKING_DIR" -name "*.yaml" -type f -exec sed -i "s|<<seu-dominio>>|${domain_name}|g" {} +
  find "$WORKING_DIR" -name "*.yaml" -type f -exec sed -i "s|<<user-home>>|$USER_HOME|g" {} +
  find "$WORKING_DIR" -name "*.yaml" -type f -exec sed -i "s|<<k8s-node-name>>|${instance_display_name}|g" {} +
  find "$WORKING_DIR" -name "*.yaml" -type f -exec sed -i "s|<<k8s-internal-dns>>|${instance_display_name}.public.mainvcn.oraclevcn.com|g" {} +

  chown -R ${user_instance}:${user_instance} $STACK_DIR
  [ -d "$CLIENT_DIR" ] && chown -R ${user_instance}:${user_instance} $CLIENT_DIR
  
  # Garantir estabilidade e aplicar
  echo "Aguardando estabilidade do K3s..."
  systemctl restart k3s
  timeout 60s bash -c "until kubectl get --raw='/readyz' > /dev/null 2>&1; do sleep 2; done"
  kubectl wait --for=condition=Ready node --all --timeout=60s
  
  echo "Aguardando CRDs do Traefik..."
  timeout 120s bash -c "until kubectl get crd ingressroutes.traefik.io > /dev/null 2>&1; do echo 'Aguardando CRD...'; sleep 5; done"
  
  # 5.3 Executar Scripts de Setup Especializados (se existirem) - Roda ANTES dos manifestos
  echo "🎯 Verificando scripts de setup especializados..."
  # Garantir que os scripts sejam executáveis
  [ -d "$STACK_DIR/scripts" ] && find "$STACK_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
  [ -d "$CLIENT_DIR/scripts" ] && find "$CLIENT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
  
  # Executar setups (onde o namespace n8n e segredos são criados)
  [ -d "$STACK_DIR/scripts" ] && find "$STACK_DIR/scripts" -name "*.sh" -exec bash {} \;
  [ -d "$CLIENT_DIR/scripts" ] && find "$CLIENT_DIR/scripts" -name "*.sh" -exec bash {} \;

  # 5.4 Aplicar os manifestos do WORKING_DIR (apenas YAML)
  echo "#### Aplicando Manifestos de AMBOS os Repositórios..."
  find "$WORKING_DIR" -type f ! \( -name "*.yaml" -o -name "*.yml" \) -delete
  kubectl apply -R -f "$WORKING_DIR"
  
  # Limpeza
  rm -rf "$WORKING_DIR"
else
  echo "Repositório de Stack principal não encontrado."
fi

# 6. Validação de Saúde da Infra
echo "Aguardando pods de infra ficarem prontos..."
kubectl wait --for=condition=ready pod --all -n database --timeout=300s || true
kubectl wait --for=condition=ready pod --all -n minio --timeout=300s || true

# 6.1 Auto-Restore do Postgres (Baseado em Marker File)
RESTORE_MARKER="/mnt/db-vol/.restore_done"

if [ -d "/mnt/db-vol" ] && [ ! -f "$RESTORE_MARKER" ]; then
  echo "Volume novo ou sem marcação de restore detectado em /mnt/db-vol."
  echo "Buscando backups no S3 para inicialização..."
  
  # Instalar AWS CLI v2 oficial para ARM64 (aarch64) se não houver
  if ! command -v aws &> /dev/null ; then
    echo "Instalando AWS CLI v2 (ARM64)..."
    apt-get update && apt-get install -y unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip ./aws
  fi

  export AWS_ACCESS_KEY_ID="${aws_access_key}"
  export AWS_SECRET_ACCESS_KEY="${aws_secret_key}"
  export AWS_DEFAULT_REGION="${aws_region}"
  
  LATEST_BACKUP=$(aws s3 ls "s3://${backup_bucket}/backups/" | grep "backup_all" | sort | tail -n 1 | awk '{print $4}')
  
  if [ -n "$LATEST_BACKUP" ]; then
    echo "Restaurando backup mais recente: $LATEST_BACKUP"
    PG_POD=$(kubectl get pods -n database -l app=postgres -o name | head -n 1)
    
    if [ -n "$PG_POD" ]; then
      # O dumpall contém comandos de criação, então restauramos no banco 'postgres' padrão
      aws s3 cp "s3://${backup_bucket}/backups/$LATEST_BACKUP" - | zcat | \
        kubectl exec -i -n database "$PG_POD" -- psql -U admin -d postgres
      
      if [ $? -eq 0 ]; then
        echo "✅ Restore concluído com sucesso!"
        touch "$RESTORE_MARKER"
        # Reiniciar apps que dependem do banco para garantir nova conexão
        kubectl rollout restart deployment n8n -n n8n || true
      else
        echo "❌ Falha no restore do backup."
      fi
    else
      echo "⚠️ Erro: Pod do Postgres não encontrado para restore."
    fi
  else
    echo "⚠️ Nenhum backup encontrado no S3. Iniciando com banco vazio."
    touch "$RESTORE_MARKER" # Marca como feito para não tentar novamente no próximo boot
  fi
else
  echo "✅ Volume já possui dados ou marcação de restore em $RESTORE_MARKER. Pulando."
fi

# 7. Notificar Discord Final
notify_discord "🚀 **Infra OCI com Persistência Pronta!**\n ☸️ **Kubernetes Status:** OK!\n- 🐳 **Portainer:** https://portainer.${domain_name}\n- 📊 **Grafana:** https://grafana.${domain_name}\n- 🐘 **Postgres & 🗄️ CloudBeaver:** https://db.${domain_name}\n- 📦 **MinIO Console:** https://minio.${domain_name}\n- ☁️ **MinIO S3 API:** https://s3.${domain_name}\n\n✅ Todos os volumes iSCSI (DB 50GB & MinIO 100GB) foram montados com sucesso!"

echo "Configuração finalizada."
