#!/bin/bash
# Script de Destruição Automática - OCI Modular
set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAYERS_DIR="$ROOT_DIR/terraform/layers"
VAR_FILE="$ROOT_DIR/terraform.tfvars"
AUTO_VAR_FILE="$ROOT_DIR/terraform.auto.tfvars"

# Função para rodar terraform destroy em uma camada
destroy_layer() {
  local LAYER_NAME=$1
  local LAYER_PATH="$LAYERS_DIR/$LAYER_NAME"
  
  echo "----------------------------------------------------------------"
  echo "🔥 Iniciando Destruição da Camada: $LAYER_NAME"
  echo "----------------------------------------------------------------"
  
  if [ ! -d "$LAYER_PATH" ]; then
    echo "⚠️ Camada $LAYER_NAME não encontrada, pulando..."
    return
  fi

  cd "$LAYER_PATH"
  
  # Extrair bucket dinamicamente para o backend
  STATE_BUCKET=$(grep "state_bucket_name" "$AUTO_VAR_FILE" | cut -d'=' -f2 | tr -d ' "' | xargs)

  # Inicializar com backend dinâmico
  terraform init -input=false \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="region=us-east-1"
  
  # Destroy com arquivos de variáveis do root
  terraform destroy -auto-approve \
    -var-file="$VAR_FILE" \
    -var-file="$AUTO_VAR_FILE" \
    -input=false

  echo "✅ Camada $LAYER_NAME destruída com sucesso!"
  cd "$ROOT_DIR"
}

# Função para backup de emergência antes do destroy
perform_emergency_backup() {
  echo "----------------------------------------------------------------"
  echo "📦 DISPARANDO BACKUP DE EMERGÊNCIA REMOTO (S3)..."
  echo "----------------------------------------------------------------"
  
  DOMAIN=$(grep "domain_name" "$AUTO_VAR_FILE" | cut -d'=' -f2 | tr -d ' "' | xargs)
  SSH_HOST="ssh.$DOMAIN"

  ssh -o ConnectTimeout=15 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SSH_HOST" "
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml;
    if sudo kubectl get cronjob postgres-backup-s3 -n database &> /dev/null; then
      JOB_NAME=\"emergency-backup-\$(date +%s)\"
      echo \"🚀 Criando Job de emergência: \$JOB_NAME\"
      sudo kubectl create job --from=cronjob/postgres-backup-s3 \$JOB_NAME -n database
      echo \"⏳ Aguardando upload para S3 (timeout 5 min)...\"
      sudo kubectl wait --for=condition=complete job/\$JOB_NAME -n database --timeout=300s
      echo \"✅ Backup finalizado com sucesso!\"
    else
      echo \"⚠️ CronJob de backup não encontrado. Pulando...\"
    fi
  " || echo "⚠️ Erro ao disparar backup remoto (SVR offline ou timeout)."
}

# --- MENU DE DESTRUIÇÃO ---
echo "----------------------------------------------------------------"
echo "☢️  MENU DE DESTRUIÇÃO - OCI INFRA"
echo "----------------------------------------------------------------"
echo "Escolha a camada que deseja destruir:"

COLUMNS=1
options=("02-kubernetes" "01b-volumes" "01-base-infra" "TODOS" "Sair")
PS3="Digite o número da opção: "

select opt in "${options[@]}"
do
    case "$opt" in
        "02-kubernetes")
            perform_emergency_backup
            destroy_layer "02-kubernetes"
            break
            ;;
        "01b-volumes")
            destroy_layer "01b-volumes"
            break
            ;;
        "01-base-infra")
            destroy_layer "01-base-infra"
            break
            ;;
        "TODOS")
            echo "⚠️  AVISO: Iniciando destruição completa..."
            perform_emergency_backup
            destroy_layer "02-kubernetes"
            destroy_layer "01b-volumes"
            destroy_layer "01-base-infra"
            break
            ;;
        "Sair")
            exit 0
            ;;
        *)
            echo "Opção inválida"
            ;;
    esac
done
