# Domain Configuration for SSL/TLS Certificates
# IMPORTANT: Update these values with your own domain before deploying

# Your domain name (must be registered and managed in Route53)
domain_name = "example.com"

# Subject Alternative Names for the SSL certificate
# Add additional domain names or subdomains if needed
subject_alternative_names = [
  "*.example.com", # Wildcard for all subdomains
  "www.example.com"
]
