# 🚀 OCI Cloud-Native Always Free (Arquitetura Modular)

Este repositório contém uma infraestrutura profissional, modularizada e totalmente automatizada para a **Oracle Cloud Infrastructure (OCI)**, utilizando exclusivamente recursos do nível **Always Free**. 

A solução utiliza **Terraform** para o provisionamento e **GitHub Actions** para o deploy contínuo (GitOps). O acesso é protegido por **Cloudflare Zero Trust**, eliminando a necessidade de portas públicas abertas.

---

## 🏗️ Arquitetura do Projeto

A infraestrutura é orquestrada em 4 camadas independentes, cada uma com seu próprio estado (`.tfstate`):

1.  **`01-base-infra`**: Rede (VCN, Subnets), Security Lists e o Core do Cloudflare Tunnel.
2.  **`03-database`**: Instância AMD dedicada com PostgreSQL 16 (Pilar de Persistência).
3.  **`04-storage`**: Instância AMD dedicada com MinIO (API S3 compatível) e 100GB de storage.
4.  **`02-kubernetes`**: Cluster K3s rodando em instância ARM (4 OCPU / 24GB RAM).

---

## � Passo a Passo de Configuração

### 1. Preparando o Backend AWS (S3 + IAM)
O Terraform guarda os estados da infraestrutura em arquivos `.tfstate`. Usaremos um Bucket S3 para centralizar esse controle.

#### Criar o Bucket S3
1.  Acesse o Console AWS > **S3**.
2.  **Name:** Escolha um nome único (ex: `terraform-state-seu-dominio`).
3.  **Region:** `us-east-1` (Recomendado para compatibilidade).
4.  **Block Public Access:** ☑️ Marque **"Block all public access"** (Crítico!).
5.  **Versioning:** ☑️ **Enable** (Proteção contra corrupção de estado).

#### Criar Usuário IAM (Chaves de Acesso)
1.  Vá em Console AWS > **IAM** > **Users** > **Create user** (ex: `terraform-bot`).
2.  Anexe a política **Attach policies directly** com permissão para o bucket:
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
                "Resource": ["arn:aws:s3:::SEU_BUCKET_NAME", "arn:aws:s3:::SEU_BUCKET_NAME/*"]
            }
        ]
    }
    ```
3.  Em **Security credentials**, crie uma **Access Key** e guarde o `Access Key ID` e o `Secret Access Key`.

---

### 2. Configurando o GitHub (Secrets e Variáveis)

No seu repositório GitHub, vá em **Settings** > **Secrets and variables** > **Actions** e adicione os seguintes segredos:

#### Secrets de Conectividade e OCI
| Secret | Descrição |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | Chave de acesso do usuário IAM AWS |
| `AWS_SECRET_ACCESS_KEY` | Segredo da chave IAM AWS |
| `OCI_TENANCY_OCID` | OCID do Tenancy (Console OCI > Perfil) |
| `OCI_USER_OCID` | OCID do Usuário (Console OCI > Identity) |
| `OCI_FINGERPRINT` | Fingerprint da API Key (OCI User > API Keys) |
| `OCI_PRIVATE_KEY_PEM` | Conteúdo do arquivo `.pem` da API Key OCI |
| `OCI_COMPARTMENT_OCID` | OCID do Compartimento onde os recursos serão criados |
| `TF_STATE_BUCKET_NAME`| Nome do bucket S3 criado no passo 1 |

#### Secrets de Aplicação e Monitoramento
| Secret | Descrição |
| :--- | :--- |
| `CLOUDFLARE_API_TOKEN` | Token com permissões DNS e Account Tunnel |
| `DISCORD_WEBHOOK_URL` | URL do Webhook do canal de avisos do Discord |
| `SSH_PUBLIC_KEY` | Sua chave pública SSH (ex: conteúdo do `id_ed25519.pub`) |
| `TF_VAR_GRAFANA_ADMIN_PASSWORD` | Senha inicial para o Grafana |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` | Dados do PostgreSQL |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | Dados do Storage MinIO |

---

### 3. Configuração do Código

#### Variáveis Públicas (`terraform.auto.tfvars`)
Edite este arquivo na raiz do projeto. Ele é a "fonte da verdade" para o seu domínio e região.

```hcl
region                = "sa-saopaulo-1"
domain_name           = "seu-dominio.com.br"
cloudflare_zone_id    = "xxx..." 
cloudflare_account_id = "xxx..." 
github_repo           = "https://github.com/usuario/seu-repo-manifestos.git"
state_bucket_name     = "nome-do-seu-bucket-s3"
```

---

### 4. Execução e Deploy

#### Via GitHub Actions (Recomendado)
Faça um **Push** na branch `main`. O workflow irá orquestrar as camadas na ordem correta:
1.  **Base-Infra**: Cria a rede e o túnel.
2.  **Database**: Sobe o PostgreSQL (AMD Instance).
3.  **Storage**: Sobe o MinIO 100GB (AMD Instance).
4.  **Kubernetes**: Sobe o cluster K3s (ARM Instance) e instala os apps.

#### Gerenciamento Manual (Local)
Para cada camada em `terraform/layers/XX-nome`, execute:
```bash
terraform init -backend-config="bucket=$BUCKET" -backend-config="region=us-east-1"
terraform apply -var-file="../../../terraform.tfvars" -var-file="../../../terraform.auto.tfvars"
```

---

## 🐳 Gerenciamento de Containers (Portainer)
Acesso visual completo ao cluster Kubernetes.
*   **URL:** `https://portainer.seu-dominio.com.br`

---

## 📊 Observabilidade e Monitoramento
Stack completa instalada no namespace `monitoring`:
*   **Grafana**: Dashboards pré-instalados (Cluster, Nodes e Logs).
*   **Prometheus / Loki**: Métricas e logs centralizados.
*   **URL:** `https://grafana.seu-dominio.com.br`

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

## ⚡ Cheat Sheet: Comandos Úteis

| Comando | Descrição |
|---------|-----------|
| `kubectl get pods -A` | Lista todos os pods no cluster. |
| `kubectl logs -f [POD] -n [NS]` | Acompanha logs em tempo real. |
| `kubectl rollout restart deploy portainer -n portainer` | Reinicia o Portainer (útil para erro de timeout de admin). |
| `tail -f /var/log/user-data.log` | Verifica o progresso do boot nas instâncias. |
| `sudo systemctl restart k3s` | Reinicia o Kubernetes no host. |
| `nc -zv [IP_INTERNO] [PORTA]` | Testa conectividade entre camadas (K8s <-> DB). |

---

### Estrutura de Diretórios Importantes
*   `terraform/layers/`: Onde vive o coração modular da infraestrutura.
*   `scripts/`: Scripts Bash otimizados para cada tipo de serviço (Postgres, MinIO, K3s).
*   `.github/workflows/`: A inteligência da automação CI/CD.

---
*Mantido com ❤️ por [Nestor Junior](https://github.com/nettaskjr)*
