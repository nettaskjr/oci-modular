#!/bin/bash
# port-audit.sh - Validação de Portas e Segurança de Rede OCI
# Autor: Antigravity (Anttaskjr AI)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Iniciando Auditoria de Portas e Segurança ===${NC}"

# 1. Definir IPs Esperados (Pode ser passado via argumento ou lido do state)
# Para este exemplo de auditoria local, vamos focar em localhost e detecção de perigo
echo -e "\n${YELLOW}[1/3] Verificando exposição externa...${NC}"

# Simulação de varredura rápida de portas comuns
CHECK_PORTS=(22 80 443 3100 5432 9000 9001 9100)

for PORT in "${CHECK_PORTS[@]}"; do
    if nc -z -w 1 localhost $PORT 2>/dev/null; then
        STATUS="${GREEN}[OPEN]${NC}"
        # Avaliar Risco
        case $PORT in
            22) RISK="${YELLOW}Atenção: SSH deve estar protegido por túnel.${NC}" ;;
            5432) RISK="${RED}CRÍTICO: Banco de dados ouvindo localmente! Verifique se está exposto ao mundo.${NC}" ;;
            9000|9001) RISK="${YELLOW}MinIO: Certifique-se que o console está sob HTTPS/Auth.${NC}" ;;
            *) RISK="${NC}Porta padrão do serviço.${NC}" ;;
        esac
        echo -e "Porta $PORT: $STATUS - $RISK"
    else
        echo -e "Porta $PORT: ${NC}[CLOSED]${NC}"
    fi
done

# 2. Verificação de Interfaces de Rede
echo -e "\n${YELLOW}[2/3] Verificando interfaces de escuta...${NC}"
if command -v ss &> /dev/null; then
    ss -tuln | grep -E "0.0.0.0|::" | grep -E "5432|22|9000" && echo -e "${RED}ALERTA: Serviços sensíveis ouvindo em 0.0.0.0!${NC}" || echo -e "${GREEN}OK: Serviços principais parecem restritos.${NC}"
else
    echo -e "${YELLOW}Aviso: 'ss' não encontrado. Pulando verificação avançada de interface.${NC}"
fi

# 3. Verificação de Regras de Firewall (UFW/IPTables)
echo -e "\n${YELLOW}[3/3] Verificando Firewall Local...${NC}"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status | head -n 1)
    if [[ $UFW_STATUS == *"active"* ]]; then
        echo -e "${GREEN}UFW está ativo.${NC}"
    else
        echo -e "${RED}AVISO: UFW está inativo na instância!${NC}"
    fi
else
    echo -e "${YELLOW}Aviso: 'ufw' não encontrado.${NC}"
fi

echo -e "\n${YELLOW}=== Auditoria Finalizada ===${NC}"
