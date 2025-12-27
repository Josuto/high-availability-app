data "aws_lb" "ingress" {
  tags = {
    "kubernetes.io/ingress-name" = "${var.namespace}/${var.app_name}-ingress"
  }
}

resource "aws_route53_record" "app" {
  zone_id = var.hosted_zone_id
  name    = var.root_domain_name
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress.dns_name
    zone_id                = data.aws_lb.ingress.zone_id
    evaluate_target_health = true
  }
}
