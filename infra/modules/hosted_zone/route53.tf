# Route 53 hosted zone, a container of DNS records of a domain. It manages where the domain points to (e.g., a web server).
resource "aws_route53_zone" "domain_zone" {
  name          = var.root_domain_name
  comment       = "Hosted zone for the domain"
  force_destroy = var.force_destroy[var.environment] # Set to false in PROD environment

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
