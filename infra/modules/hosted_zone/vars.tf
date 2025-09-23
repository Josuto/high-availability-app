variable "project_name" {
  description = "The name of the project this module belongs to"
  type        = string
}

variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

variable "force_destroy" {
  description = "Enable the destruction of the hosted zone"
  default     = false
}
