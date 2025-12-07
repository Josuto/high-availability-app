output "acm_certificate_validation_arn" {
  description = "The ARN of the validated ACM certificate for HTTPS connections"
  value       = module.ssl.acm_certificate_validation_arn
}

output "certificate_arn" {
  description = "Alias for acm_certificate_validation_arn"
  value       = module.ssl.acm_certificate_validation_arn
}
