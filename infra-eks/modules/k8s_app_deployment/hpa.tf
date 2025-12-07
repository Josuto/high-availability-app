#####################################
# Horizontal Pod Autoscaler
#####################################

resource "kubernetes_horizontal_pod_autoscaler_v2" "app" {
  count = var.enable_autoscaling ? 1 : 0

  metadata {
    name      = "${var.app_name}-hpa"
    namespace = var.namespace

    labels = merge(
      local.common_labels,
      {
        app = var.app_name
      }
    )
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.app.metadata[0].name
    }

    min_replicas = var.min_replicas[var.environment]
    max_replicas = var.max_replicas[var.environment]

    # CPU-based scaling
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = var.cpu_target_utilization
        }
      }
    }

    # Memory-based scaling
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = var.memory_target_utilization
        }
      }
    }

    # Scaling behavior configuration
    behavior {
      # Scale down behavior
      scale_down {
        stabilization_window_seconds = 300 # Wait 5 minutes before scaling down

        policy {
          type           = "Percent"
          value          = 50 # Scale down by max 50% of current pods
          period_seconds = 60
        }
      }

      # Scale up behavior
      scale_up {
        stabilization_window_seconds = 0 # Scale up immediately

        policy {
          type           = "Percent"
          value          = 100 # Double the number of pods
          period_seconds = 30
        }

        policy {
          type           = "Pods"
          value          = 2 # Add 2 pods at a time
          period_seconds = 30
        }

        select_policy = "Max" # Use the policy that scales up the most
      }
    }
  }
}
