# This ECS ALB is the core component that distributes incoming application traffic across multiple targets, such as ECS tasks (i.e., containers).
resource "aws_alb" "alb" {
  name            = "${var.environment}-${var.project_name}-alb"
  internal        = false                       # Determines if the ALB is internal (accessible from within the VPC via a private IP) or Internet-facing (accessible from the Internet via a public IP)
  security_groups = [aws_security_group.alb.id] # The security groups that are associated with the ALB
  subnets         = var.vpc_public_subnets      # The ALB must be deployed into at least two Availability Zones for high availability

  enable_deletion_protection = var.enable_deletion_protection[var.environment] # Set to true in PROD environments to prevent the accidental deletion of the ALB
  drop_invalid_header_fields = true                                            # Drop HTTP headers with invalid fields to prevent potential security risks

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# HTTPS listener
# To accept incoming HTTPS connections, decrypt them using the specified certificate, and forward the unencrypted traffic to the configured
# target group (your ECS services).
resource "aws_alb_listener" "alb_https" {
  load_balancer_arn = aws_alb.alb.arn # Link this listener to the ALB
  port              = "443"           # HTTPS standard port
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06" # Dictates the SSL/TLS protocols and ciphers that are allowed for secure connections
  certificate_arn   = var.acm_certificate_validation_arn        # Attaches the retrieved ACM certificate to this listener, enabling SSL/TLS termination at the ALB i.e., all traffic encrypted with this certificate will be decrypted by the ALB

  default_action {                                          # Defines what the listener should do with incoming requests that don't match any specific rules (if you had more complex rules)
    target_group_arn = aws_alb_target_group.ecs_service.arn # Specifies the ARN of the default target group (defines your ECS service's tasks) to which requests will be forwarded
    type             = "forward"                            # Indicates that the action is to forward the request to the specified target group
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# HTTP listener
# Redirect all HTTP requests to HTTPS requests. To do so, the ALB is to issue a redirect response to the client so that it makes an HTTPS request
# instead.
resource "aws_alb_listener" "alb_http" {
  load_balancer_arn = aws_alb.alb.arn # Link this listener to the ALB
  port              = "80"            # HTTP standard port
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"      # Specify the port to redirect to, which is the standard HTTPS port
      protocol    = "HTTPS"    # Specify the protocol to redirect to
      status_code = "HTTP_301" # Use a 301 status code for a permanent redirect. This is good for SEO and tells browsers to cache the redirect.
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
