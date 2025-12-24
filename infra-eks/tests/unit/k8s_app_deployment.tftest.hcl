# Test suite for Kubernetes Application Deployment module
# Tests deployment, service, HPA, ingress, and environment-specific configurations

provider "aws" {
  region                      = "eu-west-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "k8s_deployment_basic_configuration" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/dev-test-project-ecr-repository"
    image_tag          = "dev-abc123"
  }

  # Test deployment name
  assert {
    condition     = kubernetes_deployment.app.metadata[0].name == "nestjs-app-deployment"
    error_message = "Deployment name should follow naming convention"
  }

  # Test deployment namespace
  assert {
    condition     = kubernetes_deployment.app.metadata[0].namespace == "default"
    error_message = "Deployment should be in default namespace"
  }

  # Test deployment replicas for dev
  assert {
    condition     = kubernetes_deployment.app.spec[0].replicas == "2"
    error_message = "Deployment should have 2 replicas for dev"
  }
}

run "k8s_deployment_prod_replicas" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "prod"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/prod-test-project-ecr-repository"
    image_tag          = "prod-xyz789"
    replica_count = {
      dev  = 2
      prod = 3
    }
  }

  # Test deployment replicas for prod
  assert {
    condition     = kubernetes_deployment.app.spec[0].replicas == "3"
    error_message = "Deployment should have 3 replicas for prod"
  }
}

run "k8s_deployment_container_configuration" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "my-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "v1.2.3"
    container_port     = 8080
  }

  # Test container image
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].image == "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo:v1.2.3"
    error_message = "Container should use correct image with tag"
  }

  # Test container name
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].name == "my-app"
    error_message = "Container name should match app name"
  }

  # Test container port
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].port[0].container_port == 8080
    error_message = "Container should expose specified port"
  }

  # Test port protocol
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].port[0].protocol == "TCP"
    error_message = "Container port should use TCP protocol"
  }
}

run "k8s_deployment_resources_dev" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    memory_request = {
      dev  = "256Mi"
      prod = "512Mi"
    }
    cpu_request = {
      dev  = "125m"
      prod = "250m"
    }
  }

  # Test memory request for dev
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].resources[0].requests["memory"] == "256Mi"
    error_message = "Container should request 256Mi memory for dev"
  }

  # Test CPU request for dev
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].resources[0].requests["cpu"] == "125m"
    error_message = "Container should request 125m CPU for dev"
  }
}

run "k8s_deployment_resources_prod" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "prod"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    memory_limit = {
      dev  = "512Mi"
      prod = "1024Mi"
    }
    cpu_limit = {
      dev  = "250m"
      prod = "500m"
    }
  }

  # Test memory limit for prod
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].resources[0].limits["memory"] == "1024Mi"
    error_message = "Container should limit memory to 1024Mi for prod"
  }

  # Test CPU limit for prod
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].resources[0].limits["cpu"] == "500m"
    error_message = "Container should limit CPU to 500m for prod"
  }
}

run "k8s_deployment_health_probes" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    health_check_path  = "/healthz"
    container_port     = 3000
  }

  # Test liveness probe path
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].liveness_probe[0].http_get[0].path == "/healthz"
    error_message = "Liveness probe should use specified health check path"
  }

  # Test liveness probe port
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].liveness_probe[0].http_get[0].port == "3000"
    error_message = "Liveness probe should check specified port"
  }

  # Test readiness probe path
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].readiness_probe[0].http_get[0].path == "/healthz"
    error_message = "Readiness probe should use specified health check path"
  }

  # Test liveness probe initial delay
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].liveness_probe[0].initial_delay_seconds == 30
    error_message = "Liveness probe should have 30 second initial delay"
  }

  # Test readiness probe initial delay
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].readiness_probe[0].initial_delay_seconds == 10
    error_message = "Readiness probe should have 10 second initial delay"
  }
}

run "k8s_deployment_security_context" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
  }

  # Test run as non-root
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].security_context[0].run_as_non_root == true
    error_message = "Container should run as non-root user"
  }

  # Test privilege escalation is disabled
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].security_context[0].allow_privilege_escalation == false
    error_message = "Container should not allow privilege escalation"
  }

  # Test run as user
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].container[0].security_context[0].run_as_user == "1001"
    error_message = "Container should run as user 1001"
  }

  # Test pod fs_group
  assert {
    condition     = kubernetes_deployment.app.spec[0].template[0].spec[0].security_context[0].fs_group == "1000"
    error_message = "Pod should have fs_group set to 1000"
  }
}

run "k8s_deployment_rolling_update_strategy" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
  }

  # Test deployment strategy type
  assert {
    condition     = kubernetes_deployment.app.spec[0].strategy[0].type == "RollingUpdate"
    error_message = "Deployment should use RollingUpdate strategy"
  }

  # Test max unavailable
  assert {
    condition     = kubernetes_deployment.app.spec[0].strategy[0].rolling_update[0].max_unavailable == "25%"
    error_message = "RollingUpdate should allow max 25% unavailable"
  }

  # Test max surge
  assert {
    condition     = kubernetes_deployment.app.spec[0].strategy[0].rolling_update[0].max_surge == "25%"
    error_message = "RollingUpdate should allow max 25% surge"
  }
}

run "k8s_service_account" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "my-service"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
  }

  # Test service account name
  assert {
    condition     = kubernetes_service_account.app.metadata[0].name == "my-service-sa"
    error_message = "Service account name should follow naming convention"
  }

  # Test service account namespace
  assert {
    condition     = kubernetes_service_account.app.metadata[0].namespace == "default"
    error_message = "Service account should be in default namespace"
  }

  # Test automount token is enabled
  assert {
    condition     = kubernetes_service_account.app.automount_service_account_token == true
    error_message = "Service account should automount token"
  }
}

run "k8s_service_account_with_iam_role" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    iam_role_arn       = "arn:aws:iam::123456789012:role/my-app-role"
  }

  # Test service account has IAM role annotation
  assert {
    condition     = kubernetes_service_account.app.metadata[0].annotations["eks.amazonaws.com/role-arn"] == "arn:aws:iam::123456789012:role/my-app-role"
    error_message = "Service account should have IAM role annotation"
  }
}

run "k8s_service_configuration" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    container_port     = 8080
  }

  # Test service name
  assert {
    condition     = kubernetes_service.app.metadata[0].name == "nestjs-app-service"
    error_message = "Service name should follow naming convention"
  }

  # Test service type
  assert {
    condition     = kubernetes_service.app.spec[0].type == "NodePort"
    error_message = "Service should be NodePort type"
  }

  # Test service port
  assert {
    condition     = kubernetes_service.app.spec[0].port[0].port == 80
    error_message = "Service should expose port 80"
  }

  # Test service target port
  assert {
    condition     = kubernetes_service.app.spec[0].port[0].target_port == "8080"
    error_message = "Service should target container port"
  }

  # Test session affinity disabled by default
  assert {
    condition     = kubernetes_service.app.spec[0].session_affinity == "None"
    error_message = "Service should have session affinity disabled by default"
  }
}

run "k8s_service_session_affinity" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    app_name                = "nestjs-app"
    ecr_repository_url      = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag               = "latest"
    enable_session_affinity = true
  }

  # Test session affinity enabled
  assert {
    condition     = kubernetes_service.app.spec[0].session_affinity == "ClientIP"
    error_message = "Service should have ClientIP session affinity when enabled"
  }
}

run "k8s_hpa_enabled" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "dev"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    enable_autoscaling = true
    min_replicas = {
      dev  = 2
      prod = 3
    }
    max_replicas = {
      dev  = 5
      prod = 10
    }
  }

  # Test HPA name
  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app[0].metadata[0].name == "nestjs-app-hpa"
    error_message = "HPA name should follow naming convention"
  }

  # Test HPA min replicas for dev
  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].min_replicas == 2
    error_message = "HPA should have min 2 replicas for dev"
  }

  # Test HPA max replicas for dev
  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].max_replicas == 5
    error_message = "HPA should have max 5 replicas for dev"
  }

  # Test HPA scale target references deployment
  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].scale_target_ref[0].name == "nestjs-app-deployment"
    error_message = "HPA should target the deployment"
  }
}

run "k8s_hpa_prod_scaling" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "prod"
    app_name           = "nestjs-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "latest"
    enable_autoscaling = true
    min_replicas = {
      dev  = 2
      prod = 3
    }
    max_replicas = {
      dev  = 5
      prod = 10
    }
  }

  # Test HPA min replicas for prod
  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].min_replicas == 3
    error_message = "HPA should have min 3 replicas for prod"
  }

  # Test HPA max replicas for prod
  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.app[0].spec[0].max_replicas == 10
    error_message = "HPA should have max 10 replicas for prod"
  }
}

run "k8s_ingress_enabled" {
  command = plan

  variables {
    project_name        = "test-project"
    environment         = "dev"
    app_name            = "nestjs-app"
    ecr_repository_url  = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag           = "latest"
    enable_ingress      = true
    acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  }

  override_resource {
    target = kubernetes_ingress_v1.app[0]
    values = {
      metadata = {
        annotations = {
          "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
        }
      }
    }
  }

  # Test ingress name
  assert {
    condition     = kubernetes_ingress_v1.app[0].metadata[0].name == "nestjs-app-ingress"
    error_message = "Ingress name should follow naming convention"
  }

  # Test ingress class
  assert {
    condition     = kubernetes_ingress_v1.app[0].spec[0].ingress_class_name == "alb"
    error_message = "Ingress should use alb ingress class"
  }

  # Test ingress scheme annotation
  assert {
    condition     = can(regex("internet-facing", kubernetes_ingress_v1.app[0].metadata[0].annotations["alb.ingress.kubernetes.io/scheme"]))
    error_message = "Ingress should be internet-facing by default"
  }

  # Test target type annotation
  assert {
    condition     = kubernetes_ingress_v1.app[0].metadata[0].annotations["alb.ingress.kubernetes.io/target-type"] == "ip"
    error_message = "Ingress should use ip target type"
  }
}

run "k8s_ingress_https_configuration" {
  command = plan

  variables {
    project_name        = "test-project"
    environment         = "dev"
    app_name            = "nestjs-app"
    ecr_repository_url  = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag           = "latest"
    enable_ingress      = true
    enable_https        = true
    acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789012:certificate/cert-id"
  }

  override_resource {
    target = kubernetes_ingress_v1.app[0]
    values = {
      metadata = {
        annotations = {
          "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
          "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
          "alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:eu-west-1:123456789012:certificate/cert-id"
        }
      }
    }
  }

  # Test HTTPS is enabled in listen ports
  assert {
    condition     = can(regex("HTTPS", kubernetes_ingress_v1.app[0].metadata[0].annotations["alb.ingress.kubernetes.io/listen-ports"]))
    error_message = "Ingress should listen on HTTPS port"
  }

  # Test SSL redirect annotation
  assert {
    condition     = kubernetes_ingress_v1.app[0].metadata[0].annotations["alb.ingress.kubernetes.io/ssl-redirect"] == "443"
    error_message = "Ingress should redirect HTTP to HTTPS"
  }

  # Test certificate ARN annotation
  assert {
    condition     = kubernetes_ingress_v1.app[0].metadata[0].annotations["alb.ingress.kubernetes.io/certificate-arn"] == "arn:aws:acm:eu-west-1:123456789012:certificate/cert-id"
    error_message = "Ingress should use specified ACM certificate"
  }
}

run "k8s_deployment_labels" {
  command = plan

  variables {
    project_name       = "test-project"
    environment        = "prod"
    app_name           = "my-app"
    ecr_repository_url = "123456789012.dkr.ecr.eu-west-1.amazonaws.com/repo"
    image_tag          = "v2.0.0"
  }

  # Test deployment has Kubernetes standard labels
  assert {
    condition     = kubernetes_deployment.app.metadata[0].labels["app.kubernetes.io/name"] == "my-app"
    error_message = "Deployment should have standard Kubernetes name label"
  }

  # Test deployment has instance label
  assert {
    condition     = kubernetes_deployment.app.metadata[0].labels["app.kubernetes.io/instance"] == "my-app-prod"
    error_message = "Deployment should have instance label with environment"
  }

  # Test deployment has version label
  assert {
    condition     = kubernetes_deployment.app.metadata[0].labels["app.kubernetes.io/version"] == "v2.0.0"
    error_message = "Deployment should have version label matching image tag"
  }

  # Test deployment has environment label
  assert {
    condition     = kubernetes_deployment.app.metadata[0].labels["environment"] == "prod"
    error_message = "Deployment should have environment label"
  }
}
