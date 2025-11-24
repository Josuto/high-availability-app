# DNS A record for the root domain that points to the ALB
resource "aws_route53_record" "root-domain-record" {
  name    = var.root_domain_name
  zone_id = var.hosted_zone_id
  type    = "A"
  alias { # Alias to point directly to the ALB
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

# DNS A record for the www domain that points to the ALB
# We could have created a CNAME record to redirect HTTP requests to HTTPS requests, but this logic is centralised at the ALB
# level via a HTTP listener, which is a better practice.
resource "aws_route53_record" "www-domain-record" {
  name    = var.www_domain_name
  zone_id = var.hosted_zone_id
  type    = "A"
  alias { # Alias to point directly to the ALB
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}
