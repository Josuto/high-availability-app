# 1. Request the SSL certificate to the domain registrar via AWS Certificate Manager (ACM)
# This certificate will be used by the HTTPS listener to enable secure communication.
resource "aws_acm_certificate" "certificate" {
  domain_name               = var.root_domain_name
  validation_method         = "DNS"
  subject_alternative_names = [var.subject_alternative_name] # Include the wildcard domain as a Subject Alternative Name (SAN)

  # This is a good practice to ensure the new certificate is created before the old one is destroyed, minimizing downtime.
  lifecycle {
    create_before_destroy = true
  }
}

# 2. Create the Route 53 validation records
# We use a `for_each` loop to handle both the root domain and the SAN.
# This record is defined here since it is a temporary, behind-the-scenes record for AWS's internal validation process only.
resource "aws_route53_record" "certificate_validation" {
  for_each = {
    for dvo in aws_acm_certificate.certificate.domain_validation_options : dvo.domain_name => dvo
  }

  allow_overwrite = true
  name            = each.value.resource_record_name
  type            = each.value.resource_record_type
  zone_id         = var.hosted_zone_id
  records         = [each.value.resource_record_value]
  ttl             = 60
}

# 3. Wait for the certificate to be validated
resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = aws_acm_certificate.certificate.arn
  # This tells Terraform to wait for the validation records to be created and propagated
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

# 4. Update the ALB HTTPS listener to use the ARN of the validated certificate (see the ALB configuration)
