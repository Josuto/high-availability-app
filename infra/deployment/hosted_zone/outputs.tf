output "hosted_zone_id" {
  description = "The ID of the Route53 hosted zone for DNS management"
  value       = module.hosted_zone.hosted_zone_id
}
