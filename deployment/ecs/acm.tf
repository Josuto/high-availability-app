# 1. Use a data source to look up the existing certificate at the AWS Certificate Manager (ACM)
# This certificate will be used by the HTTPS listener to enable secure communication.
data "aws_acm_certificate" "existing_certificate" {
  domain   = "${var.ACM_CERTIFICATE_DOMAIN}" # Specifies the domain name of the ACM certificate to retrieve
  statuses = ["ISSUED", "PENDING_VALIDATION"] # Filter that tells Terraform to find certificates that are either ISSUED (ready to use) or PENDING_VALIDATION (currently being validated, but still potentially useful for setting up listeners if you plan to validate it shortly)
}

# 2.1. Create the CNAME validation record for the root domain
resource "aws_route53_record" "root_certificate_validation" {
  allow_overwrite = true
  name            = var.root_validation_name
  type            = "CNAME"
  zone_id         = aws_route53_zone.my-domain-zone.zone_id
  records         = [var.root_validation_value]
  ttl             = 60
}

# 2.2. Create the CNAME validation record for the wildcard subdomain
resource "aws_route53_record" "wildcard_certificate_validation" {
  allow_overwrite = true
  name            = var.wildcard_validation_name
  type            = "CNAME"
  zone_id         = aws_route53_zone.my-domain-zone.zone_id
  records         = [var.wildcard_validation_value]
  ttl             = 60
}


# 3. Wait for the certificate to be validated
resource "aws_acm_certificate_validation" "certificate_validation" {
  certificate_arn         = data.aws_acm_certificate.existing_certificate.arn
  validation_record_fqdns = [
    aws_route53_record.root_certificate_validation.fqdn,
    aws_route53_record.wildcard_certificate_validation.fqdn,
  ]
}

# 4. Update the ALB HTTPS listener to use the ARN of the validated certificate (see the ALB configuration)
