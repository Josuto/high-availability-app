#####################################
# Kubernetes Ingress (AWS Load Balancer Controller)
#####################################

resource "kubernetes_ingress_v1" "app" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "${var.app_name}-ingress"
    namespace = var.namespace

    labels = merge(
      local.common_labels,
      {
        app = var.app_name
      }
    )

    annotations = merge(
      {
        # AWS Load Balancer Controller annotations
        "alb.ingress.kubernetes.io/scheme"      = var.alb_scheme
        "alb.ingress.kubernetes.io/target-type" = "ip"

        # Health check configuration
        "alb.ingress.kubernetes.io/healthcheck-path"             = var.health_check_path
        "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "30"
        "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
        "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
        "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "2"
        "alb.ingress.kubernetes.io/success-codes"                = "200"

        # Load balancer attributes
        "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"

        # Tags for the ALB
        "alb.ingress.kubernetes.io/tags" = join(",", [
          for k, v in local.common_tags : "${k}=${v}"
        ])
      },
      var.enable_https ? {
        "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
        "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn
        } : {
        "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\": 80}]"
      },
      var.additional_ingress_annotations
    )
  }

  spec {
    ingress_class_name = "alb"

    rule {
      host = var.root_domain_name # e.g. api.example.com

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.app.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # Wait for the ALB to be created
  wait_for_load_balancer = true

  timeouts {
    create = "10m"
    delete = "10m"
  }
}
