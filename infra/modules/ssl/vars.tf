# "josumartinez.com"
variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

# "*.josumartinez.com"
variable "subject_alternative_name" {
  description = "The subject alternative name e.g., a wildcard domain"
  type        = string
}

# aws_route53_zone.domain-zone.zone_id
variable "hosted_zone_id" {
  description = "The hosted zone ID"
  type        = string
}
