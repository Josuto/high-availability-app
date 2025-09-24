# An AWS Load Balancer Listener Rule determines how the load balancer routes incoming requests to different target groups based on 
# various conditions. This allows for more sophisticated routing logic than just the listener's default action. Actually, such a rule 
# will override the listener's default action if its priority is lower (e.g., 10 vs the default 50000 if no priority is specified).
#
# Examples of complex routing logic with ALBs:
# - Path-based routing: Directing requests for `/api/*` to one target group (e.g., your backend API service) and requests for `/web/*` to another (e.g., your frontend web service)
# - Host-based routing: Routing requests for `app1.example.com` to one target group and `app2.example.com` to another, allowing you to host multiple applications behind a single ALB
# - Header-based routing: Directing traffic based on custom HTTP headers, useful for A/B testing or blue/green deployments where a specific header indicates a new version
# - Method-based routing: Sending e.g., `POST` requests to a specific service endpoint while `GET` requests go elsewhere
#
# DISABLED since we do not want to allow HTTP requests; these must be redirected to HTTPS requests. See the definition of the ALB HTTP default listener
# resource "aws_lb_listener_rule" "alb_rule" {
#   listener_arn = aws_alb_listener.alb-http.arn # Amazon Resource Name (ARN) of the listener to which this rule will be attached
#   priority     = var.ALB_RULE_PRIORITY # Sets the priority for the rule. Rules are evaluated in order of their priority, from the lowest value (highest priority) to the highest value

#   action { # Action the listener rule should take when an incoming request matches its conditions
#     type             = "forward" # Other options are redirect, fixed-response, authenticate-cognito, and authenticate-oidc
#     target_group_arn = aws_alb_target_group.ecs-service.arn # The ARN of the target group to which the request should be forwarded when this rule's conditions are met
#   }

#   condition { # The criteria that an incoming request must meet for this rule to be applied
#     http_request_method { # The type of condition to evaluate e.g., host-header, path-pattern, http-header, http-request-method, query-string, source-ip
#       values = [ "GET" ]
#     }
#   }
# }