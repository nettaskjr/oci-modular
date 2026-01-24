variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "compartment_ocid" {}
variable "fingerprint" {}
variable "region" {}
variable "api_private_key_path" {}
variable "ssh_public_key_path" {}

variable "discord_webhook_url" { default = "" }

# Database Variables
variable "db_user" {
  description = "Usuário do banco de dados"
  type        = string
  default     = "app_user"
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "app_db"
}
