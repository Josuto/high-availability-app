# "josumartinez.com."
variable "root_domain_name" {
  description = "The app root domain name"
  type        = string
}

# true
variable "force_destroy" {
  description = "Enable the destruction of the hosted zone"
  default     = false
}
