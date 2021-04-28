output "project_id" {
  value = google_project.project.project_id
}

output "load_balancer_ip_address" {
  description = "IP address of the Cloud Load Balancer"
  value       = google_compute_global_address.default.address
}

output "db_user" {
  description = "Database user"
  value       = google_sql_user.user.name
}

output "db_password" {
  description = "Database password"
  value       = random_id.db_user_password.hex
}

output "db_connection_name" {
  value = google_sql_database_instance.main.connection_name
}

output "db_ssl_cert_server_cert" {
  value = google_sql_ssl_cert.client_cert.server_ca_cert
}

output "db_ssl_cert_client_cert" {
  value = google_sql_ssl_cert.client_cert.cert
}

output "db_ssl_cert_client_key" {
  value     = google_sql_ssl_cert.client_cert.private_key
  sensitive = true
}

output "db_public_ip_address" {
  value = google_sql_database_instance.main.public_ip_address
}

output "db_instance_name" {
  value = google_sql_database_instance.main.name
}
