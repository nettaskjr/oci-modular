# 📓 Anotações Rápidas - OCI Modular

## 🌐 IPs Internos (Consultar via Terraform Output)
- **Kubernetes (Subnet):** `10.0.1.0/24`
- **PostgreSQL:** `10.0.1.x` (Porta `5432`)
- **MinIO API:** `10.0.1.x` (Porta `9000`)
- **MinIO Console:** `10.0.1.x` (Porta `9001`)

## 🔑 Comandos de Acesso
### SSH via Tunnel (Kubernetes Jump Host)
```bash
ssh-add ~/.ssh/id_ed25519
ssh -A ubuntu@ssh.nettask.com.br
ssh 10.0.1.
```

### Teste de acesso ao PostgreSQL
```bash
nc -zv <IP_DO_POSTGRESQL> 5432
```

### Túnel para Console MinIO
```bash
ssh -L 9001:<IP_MINIO>:9001 ubuntu@ssh.nettask.com.br
# Acesse: http://localhost:9001
```

## 🛠️ Manutenção Local
### Init em uma camada específica
```bash
terraform -chdir=terraform/layers/0X-nome init \
  -backend-config="bucket=terraform-nettask.com.br" \
  -backend-config="region=us-east-1"
```

### Apply em uma camada específica
```bash
terraform -chdir=terraform/layers/0X-nome apply \
  -var-file="../../../terraform.tfvars" \
  -var-file="../../../terraform.auto.tfvars"
```

## 🛢️ PostgreSQL
- **Host:** IP Interno da instância DB
- **Porta:** 5432
- **Acesso:** Apenas rede `10.0.0.0/16`

## ☁️ MinIO (S3 link)
- **Endpoint:** `http://<IP_INTERNO>:9000`
- **Console:** `http://<IP_INTERNO>:9001`