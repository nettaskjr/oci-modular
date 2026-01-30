# Plano de Testes Detalhado: Infra OCI Modular

Este documento descreve os passos necessários para validar a integridade, segurança e funcionalidade da infraestrutura provisionada e das aplicações base.

## 1. Infraestrutura e Rede (Core)

### 1.1 Conectividade via Túnel
- [ ] **Teste**: Tentar conexão SSH via `ssh ssh.nettask.com.br`.
- [ ] **Resultado Esperado**: Acesso ao prompt da instância Kubernetes sem necessidade de IP público direto ou VPN.

### 1.2 Isolamento de Banco de Dados
- [ ] **Teste**: Tentar comando `ping <IP_INTERNO_DB>` a partir de uma máquina externa.
- [ ] **Resultado Esperado**: Timeout. O banco não deve responder a pings externos.
- [ ] **Teste**: Executar `nc -zv <IP_INTERNO_DB> 5432` de dentro da instância Kubernetes.
- [ ] **Resultado Esperado**: Connection successful.

## 2. Aplicações e Serviços (K8s)

### 2.1 Disponibilidade de Painéis
- [ ] **Acesso Portainer**: [https://portainer.nettask.com.br](https://portainer.nettask.com.br) - Verificar se o cluster local está visível.
- [ ] **Acesso Grafana**: [https://grafana.nettask.com.br](https://grafana.nettask.com.br) - Verificar se o login admin funciona.
- [ ] **Acesso MinIO**: [https://minio.nettask.com.br](https://minio.nettask.com.br) - Validar acesso ao console administrativo via Cloudflare Ingress.

### 2.2 Persistência de Dados
- [ ] **Teste**: Criar um bucket no MinIO, reiniciar a instância de Storage via console OCI e verificar se o bucket ainda existe.
- [ ] **Resultado Esperado**: Bucket e dados persistidos.

## 3. Observabilidade (Logs e Métricas)

### 3.1 Integridade do Loki
- [ ] **Teste**: No Grafana Explore, selecionar o DataSource `Loki` e buscar por `{job="postgresql-logs"}`.
- [ ] **Resultado Esperado**: Visualização dos logs de transação do banco de dados em tempo real.

### 3.2 Alertas Discord
- [ ] **Teste**: Forçar um erro de sincronização ou reiniciar um serviço crítico.
- [ ] **Resultado Esperado**: Recebimento de notificação automática no canal do Discord configurado.

## 4. Segurança e Auditoria

### 4.1 Varredura de Portas (Skills Automatizadas)
- [ ] **Execução**: Rodar `./tools/audit/port-audit.sh`.
- [ ] **Resultado Esperado**: Relatório "Verde" para portas permitidas e "Vermelho" para portas expostas indevidamente (ex: 5432 aberta para 0.0.0.0).

### 4.2 Limpeza de Código
- [ ] **Execução**: Rodar `./tools/audit/tf-audit.py`.
- [ ] **Resultado Esperado**: Lista de variáveis não utilizadas no `variables.tf` (limpeza técnica).
