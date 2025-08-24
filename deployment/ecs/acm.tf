# 1. Use a data source to look up the existing certificate at AWS Certificate Manager (ACM)
# Required to retrieve the ARN (Amazon Resource Name) of an existing SSL/TLS certificate managed by AWS Certificate Manager (ACM). 
# This certificate will be used by the HTTPS listener to enable secure communication.
#
# Extra note: A data source allows you to fetch information about existing AWS resources managed outside of your current Terraform configuration or 
# by a different Terraform configuration.
data "aws_acm_certificate" "certificate" {
  domain   = "${var.ACM_CERTIFICATE_DOMAIN}" # Specifies the domain name of the ACM certificate to retrieve
  statuses = ["ISSUED", "PENDING_VALIDATION"] # Filter that tells Terraform to find certificates that are either ISSUED (ready to use) or PENDING_VALIDATION (currently being validated, but still potentially useful for setting up listeners if you plan to validate it shortly)
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
  zone_id         = aws_route53_zone.my-domain-zone.zone_id
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
