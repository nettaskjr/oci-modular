#!/bin/bash
# Script de Deploy Automático - OCI Modular
set -e

# Configurações
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LAYERS_DIR="$ROOT_DIR/terraform/layers"
VAR_FILE="$ROOT_DIR/terraform.tfvars"
AUTO_VAR_FILE="$ROOT_DIR/terraform.auto.tfvars"

# Função para rodar terraform apply em uma camada
apply_layer() {
  local LAYER_NAME=$1
  local LAYER_PATH="$LAYERS_DIR/$LAYER_NAME"
  
  echo "----------------------------------------------------------------"
  echo "🚀 Iniciando Deploy da Camada: $LAYER_NAME"
  echo "----------------------------------------------------------------"
  
  cd "$LAYER_PATH"
  
  # Extrair bucket dinamicamente para o backend
  STATE_BUCKET=$(grep "state_bucket_name" "$AUTO_VAR_FILE" | cut -d'=' -f2 | tr -d ' "' | xargs)

  # Inicializar com backend dinâmico
  terraform init -input=false \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="region=us-east-1"
  
  # Apply com arquivos de variáveis do root
  terraform apply -auto-approve \
    -var-file="$VAR_FILE" \
    -var-file="$AUTO_VAR_FILE" \
    -input=false

  echo "✅ Camada $LAYER_NAME aplicada com sucesso!"
  cd "$ROOT_DIR"
}

# Ordem de Execução (Cadeia de Dependências)
echo "🎬 Iniciando Deploy Completo da Infraestrutura..."

apply_layer "01-base-infra"
apply_layer "01b-volumes"
apply_layer "02-kubernetes" 

echo "----------------------------------------------------------------"
echo "✨ INFRAESTRUTURA COMPLETA NO AR! 🥂"
echo "----------------------------------------------------------------"
