variable "state_bucket_name" {
  description = "Nome do bucket onde estão os states"
  type        = string
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "terraform-state-oci/base.tfstate"
    region = "us-east-1" # Região do bucket S3 na OCI Object Storage compatível
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "terraform-state-oci/database.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "terraform-state-oci/storage.tfstate"
    region = "us-east-1"
  }
}
