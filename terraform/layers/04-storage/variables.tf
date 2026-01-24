variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "compartment_ocid" {}
variable "fingerprint" {}
variable "region" {}
variable "api_private_key_path" {}
variable "ssh_public_key_path" {}

variable "discord_webhook_url" { default = "" }

# MinIO Variables
variable "minio_root_user" {
  description = "Usuário admin do MinIO"
  type        = string
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "Senha admin do MinIO"
  type        = string
  sensitive   = true
}

variable "domain_name" {}
