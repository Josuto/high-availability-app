# Route 53 hosted zone, a container of DNS records of a domain. It manages where the domain points to (e.g., a web server).
resource "aws_route53_zone" "my-domain-zone" {
  name    = "josumartinez.com."
  comment = "Hosted zone for my domain"
}

# DNS A record for the root domain (i.e., xyz.com)
resource "aws_route53_record" "root-domain-record" {
  name    = "josumartinez.com"
  zone_id = aws_route53_zone.my-domain-zone.zone_id
  type    = "A"
  alias {
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}

# DNS CNAME record for www.xyz.com to redirect to xyz.com
resource "aws_route53_record" "www-domain-record" {
  name    = "www.josumartinez.com"
  zone_id = aws_route53_zone.my-domain-zone.zone_id
  type    = "CNAME"
  ttl     = 300
  records = ["josumartinez.com"]
}