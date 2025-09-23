variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

variable "subject_alternative_name" {
  description = "The subject alternative name e.g., a wildcard domain"
  type        = string
}

variable "hosted_zone_id" {
  description = "The hosted zone ID"
  type        = string
}
