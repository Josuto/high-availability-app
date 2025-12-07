output "hosted_zone_id" {
  description = "The ID of the Route53 hosted zone for the domain"
  value       = aws_route53_zone.domain_zone.zone_id
}

output "name_servers" {
  description = "The name servers for the hosted zone"
  value       = aws_route53_zone.domain_zone.name_servers
}
