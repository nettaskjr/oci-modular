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

# Ordem Inversa de Execução (Respeitando Dependências)
echo "🎬 Iniciando Destruição Completa da Infraestrutura..."

destroy_layer "02-kubernetes"
destroy_layer "01b-volumes"
destroy_layer "01-base-infra"

echo "----------------------------------------------------------------"
echo "🌋 INFRAESTRUTURA COMPLETAMENTE REMOVIDA! 🔌"
echo "----------------------------------------------------------------"
