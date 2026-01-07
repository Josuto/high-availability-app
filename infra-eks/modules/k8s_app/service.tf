#####################################
# Kubernetes Service
#####################################

resource "kubernetes_service" "app" {
  metadata {
    name      = "${var.app_name}-service"
    namespace = var.namespace

    labels = merge(
      local.common_labels,
      {
        app = var.app_name
      }
    )
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      name        = "http"
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }

    type = "NodePort"

    # Session affinity for sticky sessions (optional)
    session_affinity = var.enable_session_affinity ? "ClientIP" : "None"

    dynamic "session_affinity_config" {
      for_each = var.enable_session_affinity ? [1] : []
      content {
        client_ip {
          timeout_seconds = 10800 # 3 hours
        }
      }
    }
  }
}
