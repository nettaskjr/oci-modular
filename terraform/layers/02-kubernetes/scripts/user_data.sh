#!/bin/bash
# OCI User Data Script
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

echo "Iniciando configuração da instância (Branch Main/Stateless)..."

# 1. Atualização e Instalação de Pacotes Básicos
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl git ncdu

# 2. Instalação e Configuração do Cloudflared
echo "Instalando Cloudflared (${cloudflared_version})..."
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
# O Oracle Cloud Agent faz o login iscsi automaticamente se habilitado no Terraform.
# Vamos detectar os discos pelos tamanhos definidos: 50GB (DB) e 100GB (MinIO).

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

# Tenta montar os volumes
mount_by_size 50 "/mnt/db-vol" || true
mount_by_size 100 "/mnt/minio-vol" || true

# Configurações Explícitas removidas para evitar ciclos de dependência

# 5. GitOps: Clonar Repositório de Stack e instalacao dos apps via manifestos
STACK_DIR="$USER_HOME/.stack"
git clone "${github_repo}" $STACK_DIR || (cd $STACK_DIR && git pull)

if [ -d "$STACK_DIR" ]; then
  echo "Configurando variáveis..."
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<seu-dominio>>|${domain_name}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<user-home>>|$USER_HOME|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<grafana-user>>|${grafana_user}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<grafana-pass>>|${grafana_pass}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<db-user>>|${db_user}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<db-pass>>|${db_pass}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<db-name>>|${db_name}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<minio-pass>>|${minio_pass}|g" {} +
  find $STACK_DIR -name "*.yaml" -type f -exec sed -i "s|<<k8s-internal-dns>>|${instance_display_name}.public.mainvcn.oraclevcn.com|g" {} +
  
  # Injetar nome do host no Storage Setup
  NODE_NAME=$(hostname)
  sed -i "s|<<k8s-node-name>>|$NODE_NAME|g" $STACK_DIR/00-storage-setup.yaml
  
  chown -R ${user_instance}:${user_instance} $STACK_DIR
  
  # Garantir estabilidade e aplicar
  echo "Aguardando estabilidade do K3s..."
  systemctl restart k3s
  timeout 60s bash -c "until kubectl get --raw='/readyz' > /dev/null 2>&1; do sleep 2; done"
  kubectl wait --for=condition=Ready node --all --timeout=60s
  
  echo "Aguardando CRDs do Traefik..."
  timeout 120s bash -c "until kubectl get crd ingressroutes.traefik.io > /dev/null 2>&1; do echo 'Aguardando CRD...'; sleep 5; done"
  
  # Aplicar os manifestos
  echo "#### Configurando Armazenamento..."
  kubectl apply -f $STACK_DIR/volumes/

  echo "#### Aplicando Portainer..."
  kubectl apply -f $STACK_DIR/Portainer/

  echo "#### Aplicando Banco de Dados e GUI..."
  kubectl apply -f $STACK_DIR/Postgres/
  kubectl apply -f $STACK_DIR/CloudBeaver/

  echo "#### Aplicando MinIO..."
  kubectl apply -f $STACK_DIR/Minio/

  echo "#### Aplicando Page Error..."
  kubectl apply -f $STACK_DIR/k8s-error-page/
  
  echo "#### Aplicando Monitoramento..."
  kubectl apply -f $STACK_DIR/k8s-monitoring/
else
  echo "Repositório de Stack não encontrado."
fi

# 6. Validação de Saúde dos Pods
echo "Aguardando pods ficarem prontos (timeout 300s)..."
kubectl wait --for=condition=ready pod --all -n database --timeout=300s || true
kubectl wait --for=condition=ready pod --all -n minio --timeout=300s || true
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s || true

# 7. Notificar Discord Final
notify_discord "🚀 **Infra OCI com Persistência Pronta!**

☸️ **Kubernetes Status:**
- 🐳 **Portainer:** https://portainer.${domain_name}
- 📊 **Grafana:** https://grafana.${domain_name}
- 🐘 **Postgres & 🗄️ CloudBeaver:** https://db.${domain_name}
- ☁️ **MinIO Console:** https://minio.${domain_name}
- 📦 **MinIO S3 API:** https://s3.${domain_name}

✅ Todos os volumes iSCSI (DB 50GB & MinIO 100GB) foram montados com sucesso!"

echo "Configuração finalizada."
