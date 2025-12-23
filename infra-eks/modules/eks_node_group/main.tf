# EKS Node Group Module
# Manages EC2 instances that run Kubernetes pods
# Equivalent to ECS EC2 instances with Auto Scaling Group

resource "aws_eks_node_group" "main" {
  cluster_name    = var.eks_cluster_name
  node_group_name = "${var.eks_cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.vpc_private_subnets
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.desired_size[var.environment]
    max_size     = var.max_size[var.environment]
    min_size     = var.min_size[var.environment]
  }

  update_config {
    max_unavailable = var.max_unavailable[var.environment]
  }

  # AMI type
  ami_type = var.ami_type

  # Capacity type (ON_DEMAND or SPOT)
  capacity_type = var.capacity_type[var.environment]

  # Launch template for additional customization
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  labels = {
    Environment = var.environment
    Project     = var.project_name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.eks_cluster_name}-node-group"
    }
  )

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
    aws_iam_role_policy_attachment.eks_ssm_policy,
  ]

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
}

# Launch Template for EKS Nodes
# Provides additional customization for worker nodes

resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.eks_cluster_name}-node-"
  instance_type = var.instance_type

  # Disk configuration for worker nodes
  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.disk_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Require IMDSv2 tokens for enhanced security
    http_put_response_hop_limit = 2          # Needed for EKS (pods need to reach metadata)
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.eks_cluster_name}-node"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      local.common_tags,
      {
        Name = "${var.eks_cluster_name}-node-volume"
      }
    )
  }

  user_data = base64encode(templatefile("${path.module}/templates/userdata.sh", {
    cluster_name        = var.eks_cluster_name
    cluster_endpoint    = var.cluster_endpoint
    cluster_ca_data     = var.cluster_certificate_authority_data
    enable_spot_drainer = var.capacity_type[var.environment] == "SPOT"
  }))

  tags = local.common_tags
}
