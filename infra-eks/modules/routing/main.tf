resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = var.root_domain_name
  type    = "A"

  alias {
    name                   = var.ingress_hostname
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
