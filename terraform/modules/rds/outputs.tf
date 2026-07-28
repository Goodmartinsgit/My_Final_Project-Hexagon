output "db_endpoint" {
  description = "RDS PostgreSQL endpoint (host:port). Set as DB_HOST / DATABASE_URL in backend configuration."
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "db_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.postgres.id
}
