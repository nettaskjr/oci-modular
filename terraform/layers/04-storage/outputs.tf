output "minio_internal_ip" {
  value = oci_core_instance.minio_instance.private_ip
}

output "minio_console_url" {
  value = "http://${oci_core_instance.minio_instance.private_ip}:9001"
}
