# Data source to retrieve the AWS hosted zone, created in some previous deployment pipeline
data "aws_route53_zone" "my-domain-zone" {
  name = "josumartinez.com."
}

# DNS A record for the root domain that points to the ALB
resource "aws_route53_record" "root-domain-record" {
  name    = "josumartinez.com"
  zone_id = data.aws_route53_zone.my-domain-zone.zone_id
  type    = "A"
  alias { # Alias to point directly to the ALB
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}

# DNS A record for the www domain that points to the ALB
# We could have created a CNAME record to redirect HTTP requests to HTTPS requests, but this logic is centralised at the ALB 
# level via a HTTP listener, which is a better practice. 
resource "aws_route53_record" "www-domain-record" {
  name    = "www.josumartinez.com"
  zone_id = data.aws_route53_zone.my-domain-zone.zone_id
  type    = "A"
  alias { # Alias to point directly to the ALB
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}