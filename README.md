# 🚀 OCI Cloud-Native Always Free (Arquitetura Modular K8s)

Este repositório contém uma infraestrutura profissional, modularizada e totalmente automatizada para a **Oracle Cloud Infrastructure (OCI)**, utilizando exclusivamente recursos do nível **Always Free**. 

A solução utiliza **Terraform** para o provisionamento e **GitHub Actions** para o deploy contínuo (GitOps). O cluster Kubernetes consolidado centraliza todos os serviços, garantindo alta eficiência e persistência.

---

## 🏗️ Arquitetura do Projeto

A infraestrutura é orquestrada em 3 camadas independentes:

1.  **`01-base-infra`**: Rede (VCN, Subnets), Security Lists e o Core do Cloudflare Tunnel.
2.  **`01b-volumes`**: Gerenciamento de volumes em bloco (iSCSI) para persistência de dados.
3.  **`02-kubernetes`**: Cluster K3s rodando em instância ARM (4 OCPU / 24GB RAM). Centraliza DB, Storage e Apps.

---

## 🛠️ Serviços Consolidados no K8s

*   **PostgreSQL 16**: Banco de dados relacional com volume persistente de 50GB.
*   **MinIO**: Storage S3-compatible com volume persistente de 100GB.
*   **CloudBeaver**: Interface web para gerenciamento de banco de dados (auto-conectado).
*   **Portainer**: Gestão visual de containers e cluster.
*   **Monitoramento**: Stack completa (Grafana, Prometheus, Loki) no namespace `monitoring`.

---

## 📋 Passo a Passo de Configuração

### 1. Preparando o Backend AWS (S3 + IAM)
O Terraform guarda os estados da infraestrutura em arquivos `.tfstate` em um Bucket S3.

#### Criar o Bucket S3
1.  Acesse o Console AWS > **S3**.
2.  **Name:** Escolha um nome único (ex: `terraform-state-seu-dominio`).
3.  **Versioning:** ☑️ **Enable** (Proteção contra corrupção de estado).

### 2. Configurando o GitHub (Secrets)
Adicione os segredos em **Settings** > **Secrets and variables** > **Actions**:

| Secret | Descrição |
| :--- | :--- |
| `OCI_TENANCY_OCID` | OCID do Tenancy |
| `CLOUDFLARE_API_TOKEN`| Token DNS + Tunnel |
| `DISCORD_WEBHOOK_URL` | URL para notificações de status |
| `DB_PASSWORD` / `MINIO_ROOT_PASSWORD` | Senhas para os serviços core |

---

## 🚀 Execução e Deploy

### Automação Local (Tools)
Utilize os scripts na pasta `tools/` para facilitar o gerenciamento:

*   **Deploy**: `./infra-apply.sh` (Aplica as 3 camadas na ordem correta).
*   **Destruição**: `./infra-destroy.sh` (Menu interativo para destruir camadas específicas ou tudo).

### Via GitHub Actions
Faça um **Push** na branch `main`. O workflow irá validar e aplicar a infraestrutura automaticamente. Por segurança, a opção de **Destroy** só é permitida via script local.

---

## 🔒 Acesso Zero Trust e SSH
Esta infraestrutura **não abre portas no firewall**. Todo o tráfego é roteado pelo Cloudflare Tunnel.

**Para acessar via SSH:**
1. Instale o `cloudflared` localmente.
2. Adicione ao seu `~/.ssh/config`:
```text
Host ssh.seu-dominio.com.br
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```
3. Execute: `ssh ubuntu@ssh.seu-dominio.com.br`

---

## 📊 Observabilidade
Acesse o Grafana para monitorar o consumo de CPU, Memória e o uso dos volumes de 50GB e 100GB.
*   **URL:** `https://grafana.seu-dominio.com.br`

---

## ⚡ Cheat Sheet
| Comando | Descrição |
|---------|-----------|
| `kubectl get pods -A` | Lista todos os pods no cluster. |
| `tail -f /var/log/user-data.log` | Verifica o progresso do boot e montagem de discos. |
| `kubectl get pvc -n database` | Verifica o status dos volumes persistentes. |

---
*Mantido com ❤️ por [Nestor Junior](https://github.com/nettaskjr)*
