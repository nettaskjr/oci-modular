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


A fazer
a) criar página de manutencao no cloudflare igual a do kubernetes
b) criar arquivo de funcoes shell com as funcoes do init
c) 

Sim, com certeza você consegue ver o consumo dos volumes no Grafana! 📊🐘📦

Como instalamos o node-exporter e o kube-state-metrics, o Prometheus já está coletando esses dados. Você pode visualizar de duas formas:

1. Pelo Ponto de Montagem (Via Node Exporter)
Esta é a forma mais direta, pois monitora o disco no nível do sistema operacional. No Grafana, você pode usar estas métricas:

Espaço Livre: node_filesystem_avail_bytes{mountpoint="/mnt/db-vol"}
Espaço Total: node_filesystem_size_bytes{mountpoint="/mnt/db-vol"}
Uso em %: 
(1 - node_filesystem_avail_bytes{mountpoint="/mnt/db-vol"} / node_filesystem_size_bytes{mountpoint="/mnt/db-vol"}) * 100
2. Pelo PVC (Via Kube State Metrics)
Esta forma monitora a saúde do volume dentro do Kubernetes:

kubelet_volume_stats_used_bytes{persistentvolumeclaim="postgres-pvc"}
💡 Dica de Dashboard:
Recomendo importar o dashboard "Node Exporter Full" (ID: 1860) no seu Grafana. Ele já vem com todos os gráficos de disco prontos e você verá as partições /mnt/db-vol e /mnt/minio-vol listadas lá automaticamente.

