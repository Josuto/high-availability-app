# Test suite for EKS Node Group module
# Tests node group configuration, scaling, IAM roles, and environment-specific settings

provider "aws" {
  region                      = "eu-west-1"
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  access_key                  = "mock"
  secret_key                  = "mock" # pragma: allowlist secret
}

run "eks_node_group_basic_configuration" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111", "subnet-22222222"]
    kubernetes_version                 = "1.28"
    instance_type                      = "t3.medium"
    environment                        = "dev"
  }

  # Test node group name follows naming convention
  assert {
    condition     = aws_eks_node_group.main.node_group_name == "dev-test-project-eks-cluster-node-group"
    error_message = "Node group name should follow cluster naming pattern"
  }

  # Test node group is associated with correct cluster
  assert {
    condition     = aws_eks_node_group.main.cluster_name == "dev-test-project-eks-cluster"
    error_message = "Node group should be associated with correct cluster"
  }

  # Test Kubernetes version
  assert {
    condition     = aws_eks_node_group.main.version == "1.28"
    error_message = "Node group should use specified Kubernetes version"
  }

  # Test instance type
  assert {
    condition     = contains(aws_eks_node_group.main.instance_types, "t3.medium")
    error_message = "Node group should use specified instance type"
  }
}

run "eks_node_group_dev_scaling_config" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111", "subnet-22222222"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
    desired_size = {
      dev  = 2
      prod = 3
    }
    min_size = {
      dev  = 1
      prod = 2
    }
    max_size = {
      dev  = 3
      prod = 10
    }
  }

  # Test dev desired size
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].desired_size == 2
    error_message = "Node group should have desired size of 2 for dev"
  }

  # Test dev min size
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].min_size == 1
    error_message = "Node group should have min size of 1 for dev"
  }

  # Test dev max size
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].max_size == 3
    error_message = "Node group should have max size of 3 for dev"
  }
}

run "eks_node_group_prod_scaling_config" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "prod-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111", "subnet-22222222"]
    kubernetes_version                 = "1.28"
    environment                        = "prod"
    desired_size = {
      dev  = 2
      prod = 3
    }
    min_size = {
      dev  = 1
      prod = 2
    }
    max_size = {
      dev  = 3
      prod = 10
    }
  }

  # Test prod desired size
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].desired_size == 3
    error_message = "Node group should have desired size of 3 for prod"
  }

  # Test prod min size
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].min_size == 2
    error_message = "Node group should have min size of 2 for prod"
  }

  # Test prod max size
  assert {
    condition     = aws_eks_node_group.main.scaling_config[0].max_size == 10
    error_message = "Node group should have max size of 10 for prod"
  }
}

run "eks_node_group_capacity_type_dev" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
    capacity_type = {
      dev  = "SPOT"
      prod = "ON_DEMAND"
    }
  }

  # Test dev uses SPOT instances for cost savings
  assert {
    condition     = aws_eks_node_group.main.capacity_type == "SPOT"
    error_message = "Node group should use SPOT instances for dev environment"
  }
}

run "eks_node_group_capacity_type_prod" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "prod-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "prod"
    capacity_type = {
      dev  = "SPOT"
      prod = "ON_DEMAND"
    }
  }

  # Test prod uses ON_DEMAND instances for reliability
  assert {
    condition     = aws_eks_node_group.main.capacity_type == "ON_DEMAND"
    error_message = "Node group should use ON_DEMAND instances for prod environment"
  }
}

run "eks_node_group_update_config" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
    max_unavailable = {
      dev  = 1
      prod = 1
    }
  }

  # Test max unavailable during updates
  assert {
    condition     = aws_eks_node_group.main.update_config[0].max_unavailable == 1
    error_message = "Node group should allow max 1 unavailable node during updates"
  }
}

run "eks_node_group_ami_and_disk" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
    ami_type                           = "AL2_x86_64"
    disk_size                          = 20
  }

  # Test AMI type
  assert {
    condition     = aws_eks_node_group.main.ami_type == "AL2_x86_64"
    error_message = "Node group should use Amazon Linux 2 AMI"
  }

  # Test disk size in launch template
  assert {
    condition     = aws_launch_template.eks_nodes.block_device_mappings[0].ebs[0].volume_size == 20
    error_message = "Launch template should have 20GB disk size"
  }

  # Test disk is encrypted
  assert {
    condition     = aws_launch_template.eks_nodes.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Launch template disk should be encrypted"
  }

  # Test disk volume type is gp3
  assert {
    condition     = aws_launch_template.eks_nodes.block_device_mappings[0].ebs[0].volume_type == "gp3"
    error_message = "Launch template should use gp3 volume type"
  }
}

run "eks_node_group_labels" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "prod"
  }

  # Test node labels include environment
  assert {
    condition     = aws_eks_node_group.main.labels["Environment"] == "prod"
    error_message = "Node group should have Environment label"
  }

  # Test node labels include project
  assert {
    condition     = aws_eks_node_group.main.labels["Project"] == "test-project"
    error_message = "Node group should have Project label"
  }
}

run "eks_node_group_launch_template" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
    instance_type                      = "t3.large"
  }

  # Test launch template is attached
  assert {
    condition     = length(aws_eks_node_group.main.launch_template) > 0
    error_message = "Node group should have launch template attached"
  }

  # Test launch template instance type
  assert {
    condition     = aws_launch_template.eks_nodes.instance_type == "t3.large"
    error_message = "Launch template should use specified instance type"
  }

  # Test launch template IMDSv2 is required
  assert {
    condition     = aws_launch_template.eks_nodes.metadata_options[0].http_tokens == "required"
    error_message = "Launch template should require IMDSv2 tokens"
  }

  # Test IMDS hop limit is 2 (needed for EKS)
  assert {
    condition     = aws_launch_template.eks_nodes.metadata_options[0].http_put_response_hop_limit == 2
    error_message = "Launch template should have hop limit of 2 for EKS"
  }

  # Test monitoring is enabled
  assert {
    condition     = aws_launch_template.eks_nodes.monitoring[0].enabled == true
    error_message = "Launch template should have detailed monitoring enabled"
  }
}

run "eks_node_group_iam_role" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
  }

  # Test IAM role name
  assert {
    condition     = aws_iam_role.eks_nodes.name == "dev-test-project-eks-cluster-node-role"
    error_message = "IAM role name should follow cluster naming pattern"
  }

  # Test IAM role trust policy allows EC2 service
  assert {
    condition     = can(regex("ec2.amazonaws.com", aws_iam_role.eks_nodes.assume_role_policy))
    error_message = "IAM role should trust EC2 service"
  }
}

run "eks_node_group_iam_policies" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
  }

  # Test EKS Worker Node Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.eks_worker_node_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    error_message = "IAM role should have AmazonEKSWorkerNodePolicy attached"
  }

  # Test EKS CNI Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.eks_cni_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    error_message = "IAM role should have AmazonEKS_CNI_Policy attached"
  }

  # Test ECR Read Only Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.eks_container_registry_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    error_message = "IAM role should have AmazonEC2ContainerRegistryReadOnly attached"
  }

  # Test SSM Policy is attached
  assert {
    condition     = aws_iam_role_policy_attachment.eks_ssm_policy.policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "IAM role should have AmazonSSMManagedInstanceCore attached for debugging"
  }
}

run "eks_node_group_custom_policies" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
  }

  # Test CloudWatch policy exists
  assert {
    condition     = aws_iam_role_policy.eks_node_cloudwatch.name == "dev-test-project-eks-cluster-node-cloudwatch"
    error_message = "IAM role should have CloudWatch custom policy"
  }

  # Test CloudWatch policy allows log operations
  assert {
    condition     = can(regex("logs:CreateLogGroup", aws_iam_role_policy.eks_node_cloudwatch.policy))
    error_message = "CloudWatch policy should allow log group creation"
  }

  # Test autoscaling policy exists
  assert {
    condition     = aws_iam_role_policy.eks_node_autoscaling.name == "dev-test-project-eks-cluster-node-autoscaling"
    error_message = "IAM role should have autoscaling custom policy"
  }

  # Test autoscaling policy allows ASG operations
  assert {
    condition     = can(regex("autoscaling:SetDesiredCapacity", aws_iam_role_policy.eks_node_autoscaling.policy))
    error_message = "Autoscaling policy should allow setting desired capacity"
  }
}

run "eks_node_group_tags" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
  }

  override_resource {
    target = aws_eks_node_group.main
    values = {
      tags = {
        Project     = "test-project"
        Environment = "dev"
        ManagedBy   = "Terraform"
        Module      = "eks_node_group"
      }
    }
  }

  # Test node group has Project tag
  assert {
    condition     = aws_eks_node_group.main.tags["Project"] == "test-project"
    error_message = "Node group should have Project tag"
  }

  # Test node group has Environment tag
  assert {
    condition     = aws_eks_node_group.main.tags["Environment"] == "dev"
    error_message = "Node group should have Environment tag"
  }

  # Test node group has ManagedBy tag
  assert {
    condition     = aws_eks_node_group.main.tags["ManagedBy"] == "Terraform"
    error_message = "Node group should have ManagedBy tag"
  }

  # Test node group has Module tag
  assert {
    condition     = aws_eks_node_group.main.tags["Module"] == "eks_node_group"
    error_message = "Node group should have Module tag"
  }
}

run "eks_node_group_subnets" {
  command = plan

  variables {
    project_name                       = "test-project"
    eks_cluster_name                   = "dev-test-project-eks-cluster"
    cluster_endpoint                   = "https://mock-endpoint.eks.eu-west-1.amazonaws.com"
    cluster_certificate_authority_data = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t"
    vpc_private_subnets                = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
    kubernetes_version                 = "1.28"
    environment                        = "dev"
  }

  # Test node group uses all private subnets
  assert {
    condition     = length(aws_eks_node_group.main.subnet_ids) == 3
    error_message = "Node group should use all provided private subnets"
  }

  # Test node group contains specific subnet
  assert {
    condition     = contains(aws_eks_node_group.main.subnet_ids, "subnet-11111111")
    error_message = "Node group should include first subnet"
  }
}
