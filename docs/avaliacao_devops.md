# Avaliação DevOps - Servidor OCI

Esta avaliação analisa a infraestrutura provisionada via Terraform e os scripts de inicialização, focando na maturidade DevOps e operacional do projeto.

---

## 🔐 a) Segurança

### Pontos Fortes
- **Cloudflare Tunnels (Zero Trust):** O uso de túneis (em `terraform/layers/01-base-infra/cloudflare.tf`) é uma prática excelente. Ele oculta o IP público do servidor e elimina a necessidade de abrir portas de entrada no firewall (NAT/Port Forwarding) para serviços web.
- **Isolamento de Segredos (Relativo):** O script `user_data.sh` utiliza `mktemp` e limpa arquivos temporários, o que reduz a permanência de dados sensíveis em disco durante o provisionamento.

### Pontos de Atenção / Vulnerabilidades
> [!NOTE]
> **Correção Realizada:** O acesso direto via porta 22 (SSH) foi desabilitado no arquivo `network.tf` após esta recomendação.

- **Segredos em Texto Plano:** Muitas credenciais (senhas de banco, chaves AWS) estão sendo passadas via variáveis do Terraform e injetadas via `templatefile` no `user_data.sh`.
- *Recomendação:* Utilizar o **OCI Vault** ou o **Secrets Manager** da Oracle para buscar essas informações em tempo de execução, ou gerenciar apenas via KMS do Kubernetes.

---

## ♻️ b) Reaproveitamento de Código

### Pontos Fortes
- **Arquitetura em Camadas:** O projeto está bem organizado em camadas (`01-base-infra`, `01b-volumes`, `02-kubernetes`). Isso permite que você destrua e recrie a computação sem perder os dados dos volumes ou afetar a rede básica.
- **Uso de Terraform Remote State:** Excelente uso de `data "terraform_remote_state"` para compartilhar outputs entre camadas de forma desacoplada.

### Pontos de Atenção / Melhorias
- **Script User Data Monolítico:** O arquivo `user_data.sh` tem mais de 300 linhas e faz *muitas* coisas (update, install packages, k3s setup, git clone, database restore). Isso torna o script difícil de testar e reaproveitar para outros projetos.
- *Recomendação:* Migrar a lógica complexa de provisionamento para uma ferramenta de Gestão de Configuração como **Ansible** ou criar uma imagem pré-configurada (Golden Image) com **Packer**.

---

## 🔗 c) Acoplamento e Coesão

### Pontos Fortes
- **Alta Coesão no Terraform:** Cada camada tem uma responsabilidade clara e bem definida (Rede vs Armazenamento vs Compute).

### Pontos de Atenção / Melhorias
> [!IMPORTANT]
> **Alto Acoplamento Infra-Aplicação:** O script de infraestrutura conhece detalhes demais da aplicação (nomes de bancos de dados, usuários específicos, repositórios de clientes).
> *Impacto:* Se você quiser trocar o banco de dados de Postgres para MySQL, terá que alterar o código da infraestrutura (Terraform/User Data) e não apenas os manifestos do Kubernetes.

- **GitOps Manual:** A sincronização via `git clone` e `kubectl apply` dentro do `user_data.sh` é um "GitOps rudimentar". Se você mudar algo no Git, o servidor não atualiza automaticamente.
- *Recomendação:* Utilizar **ArgoCD** ou **FluxCD** no Kubernetes para gerenciar a reconciliação dos manifestos.

---

## 🏆 d) Melhores Práticas

### O que está excelente:
- **Resiliência no Script:** O uso de `wait_for_apt` e `set -e` demonstra preocupação com falhas silenciosas durante o boot.
- **Observabilidade Inicial:** Notificar via Webhook o status do boot é uma "best practice" de visibilidade operacional.
- **Gestão de Estado:** O uso de um backend S3 para o estado do Terraform é o padrão profissional.

### Sugestões de Evolução:
1. **Nomenclatura (Naming Convention):** Alguns recursos usam nomes genéricos como `main_vcn`. Em ambientes multi-cloud ou multi-projeto, prefixar com o nome do projeto (ex: `oci-prod-server-vcn`) ajuda na organização.
2. **Tratamento de Erros no Restore:** O processo de restore do RDS/Postgres via S3 no script de boot é criativo, mas arriscado se o banco for muito grande. Monitorar o tempo de execução do boot é crucial.
3. **Imutabilidade:** O script atual altera o estado da máquina viva (mutação). O ideal seria que a máquina já subisse quase pronta, apenas registrando o node no cluster.

---

### Veredito DevOps:
O projeto está em um nível **Intermediário/Avançado**. A base de Terraform é sólida e o uso de Cloudflare Tunnel eleva o nível de segurança. O principal gargalo está na complexidade do `user_data.sh` e no acoplamento entre a infraestrutura e a lógica da aplicação.
