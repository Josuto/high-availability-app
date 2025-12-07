output "hosted_zone_id" {
  description = "The ID of the hosted zone"
  value       = module.hosted_zone.hosted_zone_id
}

output "name_servers" {
  description = "The name servers for the hosted zone"
  value       = module.hosted_zone.name_servers
}
