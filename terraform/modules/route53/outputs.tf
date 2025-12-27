# Route53 Module - Outputs

output "mc_server_record_fqdn" {
  description = "MC Server DNS Record FQDN"
  value       = aws_route53_record.mc_server.fqdn
}

output "web_record_fqdn" {
  description = "Web Application DNS Record FQDN"
  value       = length(aws_route53_record.web) > 0 ? aws_route53_record.web[0].fqdn : ""
}
