output "db_endpoint" {
  description = "RDS PostgreSQL endpoint in host:port format. Use for display / reference only."
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

# db_address returns the hostname only (no port suffix).
# This is what gets interpolated into DATABASE_URL in the app-tier launch template.
output "db_address" {
  description = "RDS PostgreSQL hostname (address only, no port). Inject directly into DATABASE_URL."
  value       = aws_db_instance.postgres.address
  sensitive   = true
}

output "db_identifier" {
  description = "RDS instance identifier."
  value       = aws_db_instance.postgres.id
}
