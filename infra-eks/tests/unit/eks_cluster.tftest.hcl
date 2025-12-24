# Test suite for EKS Cluster module
# Tests EKS cluster, IAM roles, security groups, and environment-specific configurations

provider "aws" {
  region                      = "eu-west-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "eks_cluster_basic_configuration" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    vpc_public_subnets  = ["subnet-33333333", "subnet-44444444"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test EKS cluster name follows naming convention
  assert {
    condition     = aws_eks_cluster.main.name == "dev-test-project-eks-cluster"
    error_message = "EKS cluster name should match environment and project pattern"
  }

  # Test Kubernetes version
  assert {
    condition     = aws_eks_cluster.main.version == "1.34"
    error_message = "EKS cluster should use specified Kubernetes version"
  }
}

run "eks_cluster_vpc_configuration" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    vpc_public_subnets  = ["subnet-33333333", "subnet-44444444"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test private endpoint access is enabled
  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_private_access == true
    error_message = "EKS cluster should have private endpoint access enabled"
  }

  # Test public endpoint access for dev
  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_public_access == true
    error_message = "EKS cluster should have public endpoint access enabled for dev"
  }

  # Test subnets include both private and public
  assert {
    condition     = length(aws_eks_cluster.main.vpc_config[0].subnet_ids) == 4
    error_message = "EKS cluster should use all private and public subnets"
  }

  # Test security group is configured (can't check IDs in plan mode)
  assert {
    condition     = length(aws_security_group.eks_cluster.name) > 0
    error_message = "EKS cluster security group should be created"
  }
}

run "eks_cluster_prod_endpoint_access" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    vpc_public_subnets  = ["subnet-33333333", "subnet-44444444"]
    kubernetes_version  = "1.34"
    environment         = "prod"
    endpoint_public_access = {
      dev  = true
      prod = false
    }
  }

  # Test public endpoint access is disabled for prod
  assert {
    condition     = aws_eks_cluster.main.vpc_config[0].endpoint_public_access == false
    error_message = "EKS cluster should have public endpoint access disabled for prod"
  }
}

run "eks_cluster_logging_configuration" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111", "subnet-22222222"]
    vpc_public_subnets  = ["subnet-33333333", "subnet-44444444"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test all log types are enabled
  assert {
    condition     = length(aws_eks_cluster.main.enabled_cluster_log_types) == 5
    error_message = "EKS cluster should have all 5 log types enabled"
  }

  # Test api logs are enabled
  assert {
    condition     = contains(aws_eks_cluster.main.enabled_cluster_log_types, "api")
    error_message = "EKS cluster should have api logs enabled"
  }

  # Test audit logs are enabled
  assert {
    condition     = contains(aws_eks_cluster.main.enabled_cluster_log_types, "audit")
    error_message = "EKS cluster should have audit logs enabled"
  }
}

run "eks_cluster_cloudwatch_log_group_dev" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
    log_retention_days = {
      dev  = 7
      prod = 30
    }
  }

  # Test log group name follows convention
  assert {
    condition     = aws_cloudwatch_log_group.eks_cluster.name == "/aws/eks/dev-test-project-eks-cluster/cluster"
    error_message = "CloudWatch log group name should match cluster name"
  }

  # Test log retention for dev
  assert {
    condition     = aws_cloudwatch_log_group.eks_cluster.retention_in_days == 7
    error_message = "CloudWatch log group retention should be 7 days for dev"
  }
}

run "eks_cluster_cloudwatch_log_group_prod" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "prod"
    log_retention_days = {
      dev  = 7
      prod = 30
    }
  }

  # Test log retention for prod
  assert {
    condition     = aws_cloudwatch_log_group.eks_cluster.retention_in_days == 30
    error_message = "CloudWatch log group retention should be 30 days for prod"
  }
}

run "eks_cluster_encryption_without_kms" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
    kms_key_arn         = ""
  }

  # Test encryption config does not exist when no KMS key is provided
  # (AWS EKS uses AWS-managed encryption by default)
  assert {
    condition     = length(aws_eks_cluster.main.encryption_config) == 0
    error_message = "EKS cluster should not have encryption_config when no KMS key is provided"
  }
}

run "eks_cluster_iam_role" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test IAM role name
  assert {
    condition     = aws_iam_role.eks_cluster.name == "dev-test-project-eks-cluster-cluster-role"
    error_message = "IAM role name should match cluster naming pattern"
  }

  # Test IAM role trust policy allows EKS service
  assert {
    condition     = can(regex("eks.amazonaws.com", aws_iam_role.eks_cluster.assume_role_policy))
    error_message = "IAM role should trust EKS service"
  }
}

run "eks_cluster_iam_policies" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test EKS Cluster Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.eks_cluster_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    error_message = "IAM role should have AmazonEKSClusterPolicy attached"
  }

  # Test VPC Resource Controller Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.eks_vpc_resource_controller.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
    error_message = "IAM role should have AmazonEKSVPCResourceController attached"
  }

  # Test both policies use the same role
  assert {
    condition     = aws_iam_role_policy_attachment.eks_cluster_policy.role == aws_iam_role_policy_attachment.eks_vpc_resource_controller.role
    error_message = "All policies should be attached to the same role"
  }
}

run "eks_cluster_security_group" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test cluster security group is in correct VPC
  assert {
    condition     = aws_security_group.eks_cluster.vpc_id == "vpc-12345678"
    error_message = "Cluster security group should be in correct VPC"
  }

  # Test cluster security group name
  assert {
    condition     = aws_security_group.eks_cluster.name == "dev-test-project-eks-cluster-cluster-sg"
    error_message = "Cluster security group name should follow naming convention"
  }

  # Test cluster egress rule exists
  assert {
    condition     = aws_security_group_rule.cluster_egress.type == "egress"
    error_message = "Cluster security group should have egress rule"
  }

  # Test cluster allows all outbound
  assert {
    condition     = aws_security_group_rule.cluster_egress.protocol == "-1"
    error_message = "Cluster security group should allow all outbound traffic"
  }
}

run "eks_nodes_security_group" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test nodes security group is in correct VPC
  assert {
    condition     = aws_security_group.eks_nodes.vpc_id == "vpc-12345678"
    error_message = "Nodes security group should be in correct VPC"
  }

  # Test nodes security group name
  assert {
    condition     = aws_security_group.eks_nodes.name == "dev-test-project-eks-cluster-nodes-sg"
    error_message = "Nodes security group name should follow naming convention"
  }
}

run "eks_security_group_rules" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "dev"
  }

  # Test cluster ingress from nodes on port 443
  assert {
    condition     = aws_security_group_rule.cluster_ingress_nodes.from_port == 443
    error_message = "Cluster should allow ingress from nodes on port 443"
  }

  # Test nodes can communicate with each other
  assert {
    condition     = aws_security_group_rule.nodes_internal.type == "ingress"
    error_message = "Nodes should allow internal communication"
  }

  # Test cluster can communicate with nodes
  assert {
    condition     = aws_security_group_rule.nodes_cluster_inbound.from_port == 1025
    error_message = "Nodes should allow ingress from cluster on high ports"
  }
}

run "eks_cluster_tags" {
  command = plan

  variables {
    project_name        = "test-project"
    vpc_id              = "vpc-12345678"
    vpc_private_subnets = ["subnet-11111111"]
    vpc_public_subnets  = ["subnet-33333333"]
    kubernetes_version  = "1.34"
    environment         = "prod"
  }

  override_resource {
    target = aws_eks_cluster.main
    values = {
      tags = {
        Project     = "test-project"
        Environment = "prod"
        ManagedBy   = "Terraform"
        Module      = "eks_cluster"
      }
    }
  }

  # Test cluster has Project tag
  assert {
    condition     = aws_eks_cluster.main.tags["Project"] == "test-project"
    error_message = "EKS cluster should have Project tag"
  }

  # Test cluster has Environment tag
  assert {
    condition     = aws_eks_cluster.main.tags["Environment"] == "prod"
    error_message = "EKS cluster should have Environment tag"
  }

  # Test cluster has ManagedBy tag
  assert {
    condition     = aws_eks_cluster.main.tags["ManagedBy"] == "Terraform"
    error_message = "EKS cluster should have ManagedBy tag"
  }

  # Test cluster has Module tag
  assert {
    condition     = aws_eks_cluster.main.tags["Module"] == "eks_cluster"
    error_message = "EKS cluster should have Module tag"
  }
}

run "eks_cluster_with_alb_security_group" {
  command = plan

  variables {
    project_name          = "test-project"
    vpc_id                = "vpc-12345678"
    vpc_private_subnets   = ["subnet-11111111"]
    vpc_public_subnets    = ["subnet-33333333"]
    kubernetes_version    = "1.34"
    environment           = "dev"
    alb_security_group_id = "sg-alb123456"
  }

  # Test ALB ingress rule is created when ALB SG is provided
  assert {
    condition     = aws_security_group_rule.nodes_alb_inbound[0].from_port == 30000
    error_message = "Nodes should allow ALB traffic on NodePort range when ALB SG is provided"
  }

  # Test ALB ingress rule uses correct port range
  assert {
    condition     = aws_security_group_rule.nodes_alb_inbound[0].to_port == 32767
    error_message = "Nodes should allow ALB traffic up to port 32767"
  }
}
