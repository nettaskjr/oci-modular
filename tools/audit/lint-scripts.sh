#!/bin/bash
# lint-scripts.sh - Auditoria de Qualidade em Scripts User-Data
# Autor: Antigravity (Anttaskjr AI)

YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

BASE_PATH="../../"

echo -e "${YELLOW}=== Iniciando Auditoria de Scripts User-Data ===${NC}"

find "$BASE_PATH" -name "*.sh" | while read script; do
    echo -e "\nAnalisando: ${YELLOW}$script${NC}"
    
    # 1. Verificar set -e
    if grep -q "set -e" "$script"; then
        echo -e "${GREEN}[OK]${NC} set -e encontrado."
    else
        echo -e "${RED}[FAIL]${NC} 'set -e' ausente! O script não parará em caso de erro."
    fi

    # 2. Verificar Redundâncias (Comandos APT duplicados)
    APT_COUNT=$(grep -c "apt-get install" "$script")
    if [ "$APT_COUNT" -gt 2 ]; then
        echo -e "${YELLOW}[WARN]${NC} Detectados $APT_COUNT comandos 'apt-get install'. Considere agrupar para performance."
    fi

    # 3. Verificar Hardcoded Secrets (Padrões comuns)
    if grep -Ei "password|secret|token" "$script" | grep -qv "\${"; then
        echo -e "${RED}[ALERTA]${NC} Possível segredo Hardcoded detectado! Use variáveis do Terraform."
        grep -Ei "password|secret|token" "$script" | grep -v "\${"
    fi

    # 4. Verificar Redundâncias de Logs
    if grep -q "StandardOutput=append:" "$script"; then
        echo -e "${YELLOW}[SUGESTÃO]${NC} Detectado redirecionamento manual de logs. O Journald é preferível."
    fi

done

echo -e "\n${YELLOW}=== Auditoria Finalizada ===${NC}"
