#####################################
# Kubernetes Deployment
#####################################

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "${var.app_name}-deployment"
    namespace = var.namespace

    labels = merge(
      local.common_labels,
      {
        app = var.app_name
      }
    )
  }

  spec {
    replicas = var.replica_count[var.environment]

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = merge(
          local.common_labels,
          {
            app = var.app_name
          }
        )
      }

      spec {
        # Service Account for IRSA (IAM Roles for Service Accounts)
        service_account_name = kubernetes_service_account.app.metadata[0].name

        container {
          name  = var.app_name
          image = "${var.ecr_repository_url}:${var.image_tag}"

          port {
            container_port = var.container_port
            protocol       = "TCP"
          }

          # Resource Limits and Requests
          resources {
            requests = {
              memory = var.memory_request[var.environment]
              cpu    = var.cpu_request[var.environment]
            }
            limits = {
              memory = var.memory_limit[var.environment]
              cpu    = var.cpu_limit[var.environment]
            }
          }

          # Environment Variables
          dynamic "env" {
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }

          # Liveness Probe
          liveness_probe {
            http_get {
              path   = var.health_check_path
              port   = var.container_port
              scheme = "HTTP"
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          # Readiness Probe
          readiness_probe {
            http_get {
              path   = var.health_check_path
              port   = var.container_port
              scheme = "HTTP"
            }

            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            success_threshold     = 1
            failure_threshold     = 3
          }

          # Security Context
          security_context {
            run_as_non_root            = true
            run_as_user                = 1000
            allow_privilege_escalation = false
            read_only_root_filesystem  = false

            capabilities {
              drop = ["ALL"]
            }
          }
        }

        # Pod Security Context
        security_context {
          fs_group = 1000
        }
      }
    }

    # Deployment Strategy
    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }
  }

  # Wait for rollout to complete
  wait_for_rollout = true

  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }
}

#####################################
# Kubernetes Service Account
#####################################

resource "kubernetes_service_account" "app" {
  metadata {
    name      = "${var.app_name}-sa"
    namespace = var.namespace

    labels = local.common_labels

    # Annotation for IAM Role for Service Accounts (IRSA)
    annotations = var.iam_role_arn != "" ? {
      "eks.amazonaws.com/role-arn" = var.iam_role_arn
    } : {}
  }

  automount_service_account_token = true
}
