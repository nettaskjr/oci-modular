Para conferir se o banco está respondendo, use o seguinte comando:

```bash
nc -zv 10.0.1.66 5432
``` 

Para conectar em uma instancia que nao tem acesso ao mundo externo use o seguinte comando:

```bash
ssh-add ~/.ssh/id_ed25519
ssh -A ubuntu@ssh.nettask.com.br
ssh [ip-local]
```

Para executar o init do terraform use o seguinte comando:

```bash

```


Para executar o apply do terraform use o seguinte comando:

```bash
terraform -chdir=terraform/layers/03-database apply \
  -var-file="../../../terraform.tfvars" \
  -var-file="../../../terraform.auto.tfvars"
```