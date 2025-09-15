# Route 53 hosted zone, a container of DNS records of a domain. It manages where the domain points to (e.g., a web server).
resource "aws_route53_zone" "domain-zone" {
  name          = var.root_domain_name
  comment       = "Hosted zone for the domain"
  force_destroy = var.force_destroy # do not use this in a production environment
}
