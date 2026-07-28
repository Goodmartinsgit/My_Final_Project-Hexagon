output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "webserver_sg_id" {
  value = aws_security_group.webserver.id
}

output "appserver_sg_id" {
  value = aws_security_group.appserver.id
}

output "database_sg_id" {
  value = aws_security_group.database.id
}
