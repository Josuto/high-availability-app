# This ECS ALB is the core component that distributes incoming application traffic across multiple targets, such as ECS tasks (i.e., containers).
resource "aws_alb" "alb" {
  name            = "my-alb"
  internal        = false # Determines if the ALB is internal (accessible from within the VPC via a private IP) or Internet-facing (accessible from the Internet via a public IP)
  security_groups = [aws_security_group.alb.id] # The security groups that are associated with the ALB
  subnets         = module.vpc.public_subnets # The ALB must be deployed into at least two Availability Zones for high availability

  enable_deletion_protection = false # When set to true, prevents the accidental deletion of the ALB
}

# ACM Certificate Data Source
# Required to retrieve the ARN (Amazon Resource Name) of an existing SSL/TLS certificate managed by AWS Certificate Manager (ACM). 
# This certificate will be used by the HTTPS listener to enable secure communication.
#
# Extra note: A data source allows you to fetch information about existing AWS resources managed outside of your current Terraform configuration or 
# by a different Terraform configuration.
data "aws_acm_certificate" "certificate" {
  domain   = "${var.ACM_CERTIFICATE_DOMAIN}" # Specifies the domain name of the ACM certificate to retrieve
  statuses = ["ISSUED", "PENDING_VALIDATION"] # Filter that tells Terraform to find certificates that are either ISSUED (ready to use) or PENDING_VALIDATION (currently being validated, but still potentially useful for setting up listeners if you plan to validate it shortly)
}

# HTTPS listener
# To accept incoming HTTPS connections, decrypt them using the specified certificate, and forward the unencrypted traffic to the configured 
# target group (your ECS services).
resource "aws_alb_listener" "alb-https" {
  load_balancer_arn = aws_alb.alb.arn # Link this listener to the ALB
  port              = "443" # HTTPS standard port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06" # Dictates the SSL/TLS protocols and ciphers that are allowed for secure connections
  certificate_arn   = data.aws_acm_certificate.certificate.arn # Attaches the retrieved ACM certificate to this listener, enabling SSL/TLS termination at the ALB i.e., all traffic encrypted with this certificate will be decrypted by the ALB

  default_action { # Defines what the listener should do with incoming requests that don't match any specific rules (if you had more complex rules)
    target_group_arn = aws_alb_target_group.ecs-service.arn # Specifies the ARN of the default target group (defines your ECS service's tasks) to which requests will be forwarded
    type             = "forward" # Indicates that the action is to forward the request to the specified target group
  }
}

# HTTP listener
# Redirect all HTTP requests to HTTPS requests. To do so, the ALB is to issue a redirect response to the client so that it makes an HTTPS request 
# instead.
resource "aws_alb_listener" "alb-http" {
  load_balancer_arn = aws_alb.alb.arn # Link this listener to the ALB
  port              = "80" # HTTP standard port
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"    # Specify the port to redirect to, which is the standard HTTPS port
      protocol    = "HTTPS"  # Specify the protocol to redirect to
      status_code = "HTTP_301" # Use a 301 status code for a permanent redirect. This is good for SEO and tells browsers to cache the redirect.
    }
  }
}