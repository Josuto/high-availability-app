output "acm_certificate_validation_arn" {
  description = "The ARN of the validated ACM certificate for HTTPS connections"
  value       = module.ssl.acm_certificate_validation_arn
}
