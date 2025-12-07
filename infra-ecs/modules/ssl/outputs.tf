output "acm_certificate_validation_arn" {
  description = "The ARN of the validated ACM certificate for HTTPS"
  value       = aws_acm_certificate_validation.certificate_validation.certificate_arn
}
