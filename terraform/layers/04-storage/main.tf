variable "state_bucket_name" {
  description = "Nome do bucket onde estão os states"
  type        = string
}

data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = "terraform-state-oci/base.tfstate"
    region = "us-east-1"
  }
}
