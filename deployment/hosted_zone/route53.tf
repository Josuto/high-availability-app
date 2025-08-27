# Route 53 hosted zone, a container of DNS records of a domain. It manages where the domain points to (e.g., a web server).
resource "aws_route53_zone" "my-domain-zone" {
  name    = "josumartinez.com."
  comment = "Hosted zone for my domain"
}
