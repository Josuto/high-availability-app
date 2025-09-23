variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

variable "www_domain_name" {
  description = "The app WWW domain name"
  type        = string
}

variable "alb_dns_name" {
  description = "The DNS name of the ALB"
  type        = string
}

variable "alb_hosted_zone_id" {
  description = "The hosted zone ID of the ALB"
  type        = string
}

variable "hosted_zone_id" {
  description = "Hosted zone ID"
  type        = string
}

