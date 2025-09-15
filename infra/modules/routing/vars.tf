# "josumartinez.com"
variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

# "www.josumartinez.com"
variable "www_domain_name" {
  description = "The app WWW domain name"
  type        = string
}

# aws_alb.alb.dns_name
variable "alb_dns_name" {
  description = "The DNS name of the ALB"
  type        = string
}

# aws_alb.alb.zone_id
variable "alb_hosted_zone_id" {
  description = "The hosted zone ID of the ALB"
  type        = string
}

# aws_route53_zone.domain-zone.zone_id
variable "hosted_zone_id" {
  description = "Hosted zone ID"
  type        = string
}

