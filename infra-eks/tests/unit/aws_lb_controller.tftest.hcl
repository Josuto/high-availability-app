# Test suite for AWS Load Balancer Controller module
# Tests OIDC provider, IAM configuration, and Helm chart deployment

provider "aws" {
  region                      = "eu-west-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "aws_lb_controller_oidc_provider" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test OIDC provider client ID list
  assert {
    condition     = contains(aws_iam_openid_connect_provider.eks.client_id_list, "sts.amazonaws.com")
    error_message = "OIDC provider should have sts.amazonaws.com as client ID"
  }

  # Test OIDC provider URL
  assert {
    condition     = aws_iam_openid_connect_provider.eks.url == "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    error_message = "OIDC provider should use cluster OIDC issuer URL"
  }

  # Test OIDC provider has thumbprint
  assert {
    condition     = length(aws_iam_openid_connect_provider.eks.thumbprint_list) > 0
    error_message = "OIDC provider should have thumbprint list"
  }
}

run "aws_lb_controller_iam_policy" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test IAM policy name follows naming convention
  assert {
    condition     = aws_iam_policy.aws_load_balancer_controller.name == "dev-test-project-AWSLoadBalancerControllerIAMPolicy"
    error_message = "IAM policy name should follow naming convention"
  }

  # Test IAM policy has description
  assert {
    condition     = aws_iam_policy.aws_load_balancer_controller.description == "IAM policy for AWS Load Balancer Controller"
    error_message = "IAM policy should have descriptive description"
  }

  # Test IAM policy is not empty
  assert {
    condition     = length(aws_iam_policy.aws_load_balancer_controller.policy) > 0
    error_message = "IAM policy should have content"
  }
}

run "aws_lb_controller_iam_role" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "prod"
    cluster_name            = "prod-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test IAM role name follows naming convention
  assert {
    condition     = aws_iam_role.aws_load_balancer_controller.name == "prod-test-project-aws-load-balancer-controller"
    error_message = "IAM role name should follow naming convention"
  }

  # Test IAM role exists (computed values can't be tested in plan mode)
  assert {
    condition     = aws_iam_role.aws_load_balancer_controller.name != ""
    error_message = "IAM role should be created"
  }
}

run "aws_lb_controller_iam_role_policy_attachment" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test policy is attached to role
  assert {
    condition     = aws_iam_role_policy_attachment.aws_load_balancer_controller.role == aws_iam_role.aws_load_balancer_controller.name
    error_message = "IAM policy should be attached to correct role"
  }

  # Test policy attachment exists (ARNs are computed and can't be compared in plan mode)
  assert {
    condition     = aws_iam_role_policy_attachment.aws_load_balancer_controller.role != ""
    error_message = "IAM role attachment should be created"
  }
}

run "aws_lb_controller_service_account_default" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test service account name uses default
  assert {
    condition     = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name == "aws-load-balancer-controller"
    error_message = "Service account should have default name"
  }

  # Test service account namespace uses default
  assert {
    condition     = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].namespace == "kube-system"
    error_message = "Service account should be in kube-system namespace by default"
  }
}

run "aws_lb_controller_service_account_custom" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
    namespace               = "custom-namespace"
    service_account_name    = "custom-sa"
  }

  # Test service account uses custom name
  assert {
    condition     = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name == "custom-sa"
    error_message = "Service account should use custom name"
  }

  # Test service account uses custom namespace
  assert {
    condition     = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].namespace == "custom-namespace"
    error_message = "Service account should use custom namespace"
  }
}

run "aws_lb_controller_helm_release_default" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test Helm release name
  assert {
    condition     = helm_release.aws_load_balancer_controller.name == "aws-load-balancer-controller"
    error_message = "Helm release should have default name"
  }

  # Test Helm chart
  assert {
    condition     = helm_release.aws_load_balancer_controller.chart == "aws-load-balancer-controller"
    error_message = "Helm release should use aws-load-balancer-controller chart"
  }

  # Test Helm repository
  assert {
    condition     = helm_release.aws_load_balancer_controller.repository == "https://aws.github.io/eks-charts"
    error_message = "Helm release should use AWS EKS charts repository"
  }

  # Test Helm namespace
  assert {
    condition     = helm_release.aws_load_balancer_controller.namespace == "kube-system"
    error_message = "Helm release should be in kube-system namespace by default"
  }

  # Test Helm chart version
  assert {
    condition     = helm_release.aws_load_balancer_controller.version == "1.6.0"
    error_message = "Helm release should use default chart version"
  }

  # Test Helm wait is enabled
  assert {
    condition     = helm_release.aws_load_balancer_controller.wait == true
    error_message = "Helm release should wait for deployment"
  }

  # Test Helm wait_for_jobs is enabled
  assert {
    condition     = helm_release.aws_load_balancer_controller.wait_for_jobs == true
    error_message = "Helm release should wait for jobs"
  }

  # Test Helm timeout
  assert {
    condition     = helm_release.aws_load_balancer_controller.timeout == 600
    error_message = "Helm release should have default timeout of 600 seconds"
  }
}

run "aws_lb_controller_helm_release_custom" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
    helm_release_name       = "custom-lb-controller"
    helm_chart_version      = "1.7.0"
    helm_timeout            = 900
  }

  # Test Helm release uses custom name
  assert {
    condition     = helm_release.aws_load_balancer_controller.name == "custom-lb-controller"
    error_message = "Helm release should use custom name"
  }

  # Test Helm release uses custom version
  assert {
    condition     = helm_release.aws_load_balancer_controller.version == "1.7.0"
    error_message = "Helm release should use custom chart version"
  }

  # Test Helm release uses custom timeout
  assert {
    condition     = helm_release.aws_load_balancer_controller.timeout == 900
    error_message = "Helm release should use custom timeout"
  }
}

run "aws_lb_controller_helm_values" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-87654321"
  }

  # Test Helm values contain cluster name
  assert {
    condition     = can(regex("dev-test-project-eks-cluster", join("", helm_release.aws_load_balancer_controller.values)))
    error_message = "Helm values should contain cluster name"
  }

  # Test Helm values contain VPC ID
  assert {
    condition     = can(regex("vpc-87654321", join("", helm_release.aws_load_balancer_controller.values)))
    error_message = "Helm values should contain VPC ID"
  }

  # Test Helm values specify not to create service account
  assert {
    condition     = can(regex("create.*false", join("", helm_release.aws_load_balancer_controller.values)))
    error_message = "Helm values should not create service account (pre-created)"
  }
}

run "aws_lb_controller_tags" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "prod"
    cluster_name            = "prod-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
    tags = {
      Team = "platform"
      Cost = "shared"
    }
  }

  # Test OIDC provider has custom tags
  assert {
    condition     = aws_iam_openid_connect_provider.eks.tags["Team"] == "platform"
    error_message = "OIDC provider should have custom tags"
  }

  # Test IAM policy has custom tags
  assert {
    condition     = aws_iam_policy.aws_load_balancer_controller.tags["Cost"] == "shared"
    error_message = "IAM policy should have custom tags"
  }

  # Test IAM role has custom tags
  assert {
    condition     = aws_iam_role.aws_load_balancer_controller.tags["Team"] == "platform"
    error_message = "IAM role should have custom tags"
  }
}

run "aws_lb_controller_oidc_provider_tags" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "dev"
    cluster_name            = "dev-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test OIDC provider has Name tag
  assert {
    condition     = aws_iam_openid_connect_provider.eks.tags["Name"] == "dev-test-project-eks-oidc"
    error_message = "OIDC provider should have Name tag following naming convention"
  }
}

run "aws_lb_controller_variable_validation" {
  command = plan

  variables {
    project_name            = "test-project"
    environment             = "staging"
    cluster_name            = "staging-test-project-eks-cluster"
    cluster_oidc_issuer_url = "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    vpc_id                  = "vpc-12345678"
  }

  # Test non-standard environment is accepted
  assert {
    condition     = aws_iam_openid_connect_provider.eks.url == "https://oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLED539D4633E53DE44EEA84CEC"
    error_message = "Module should accept any environment string"
  }
}
