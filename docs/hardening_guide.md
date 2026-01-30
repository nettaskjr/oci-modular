# Guia de Hardening e Melhores Práticas (OCI Modular)

Este guia consolida as recomendações de segurança e otimização para o projeto, baseando-se nos diagnósticos realizados pelas ferramentas de auditoria.

## 1. Segurança de Rede (Hardening)

> [!CAUTION]
> Atualmente, a porta 22 (SSH) está aberta na VCN. Embora protegida por chave, a melhor prática é restringir o acesso apenas aos IPs internos do Cloudflare Tunnel.

### Recomendações:
- **Zero Trust SSH**: Desabilitar SSH via IP público e permitir apenas via `cloudflared access`.
- **DB Isolation**: O banco de dados já está isolado na rede interna (10.0.1.0/24), o que é excelente.
- **WAF**: Ativar as regras de Web Application Firewall do Cloudflare para os subdomínios expostos (Grafana, MinIO).

## 2. Otimização de Automação (Shell Scripts)

Baseado no achado do `lint-scripts.sh`:

- **Agrupamento de Pacotes**: Evitar múltiplos `apt-get install`. Agrupar em um único comando reduz o tempo de provisionamento e o risco de inconsistência de metadados do `apt`.
- **Error Handling**: Todos os scripts devem começar com `set -e` para evitar que a execução continue em caso de falha de um comando crítico.

## 3. Gestão de Configuração (Terraform)

- **DRY (Don't Repeat Yourself)**: Notamos redundâncias potenciais em Security Lists. Recomenda-se modularizar as regras de segurança comuns.
- **Variable Hygiene**: Regularmente rodar o `tf-audit.py` para remover variáveis que sobraram de versões anteriores do projeto.

## 4. Checklist de Saúde Diária
1. Rodar `./tools/audit/port-audit.sh` semanalmente.
2. Verificar no Grafana se os labels `postgresql-logs` e `minio-logs` estao com batimento cardíaco constante.
3. Validar se não há pods no status `CrashLoopBackOff` via Portainer.
