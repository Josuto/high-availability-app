#####################################
# AWS Load Balancer Controller Module
#####################################
# This module deploys the AWS Load Balancer Controller to an EKS cluster
# It handles:
# - OIDC provider creation for IRSA (IAM Roles for Service Accounts)
# - IAM policy and role for the controller
# - Kubernetes service account
# - Helm chart deployment

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

#####################################
# Get Current AWS Account and Region
#####################################

data "aws_region" "current" {}

#####################################
# OIDC Provider for EKS
#####################################

# Get the TLS certificate for the EKS cluster's OIDC issuer
data "tls_certificate" "eks" {
  url = var.cluster_oidc_issuer_url
}

# Create OIDC provider for the EKS cluster
# This enables IAM Roles for Service Accounts (IRSA)
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = var.cluster_oidc_issuer_url

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.project_name}-eks-oidc"
    }
  )
}

#####################################
# IAM Policy for AWS Load Balancer Controller
#####################################

# Create IAM policy with permissions for the Load Balancer Controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "${var.environment}-${var.project_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "IAM policy for AWS Load Balancer Controller"
  policy      = file("${path.module}/iam_policy.json")

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.project_name}-lb-controller-policy"
    }
  )
}

#####################################
# IAM Role for AWS Load Balancer Controller
#####################################

# Create assume role policy document for the service account
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# Create IAM role for the Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name               = "${var.environment}-${var.project_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.project_name}-lb-controller-role"
    }
  )
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

#####################################
# Kubernetes Service Account
#####################################

# Create Kubernetes service account for the Load Balancer Controller
resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.aws_load_balancer_controller.arn
    }
  }
}

#####################################
# Helm Release for AWS Load Balancer Controller
#####################################

# Deploy the AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = var.helm_release_name
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = var.namespace
  version    = var.helm_chart_version

  values = [
    yamlencode({
      clusterName = var.cluster_name
      serviceAccount = {
        create = false
        name   = kubernetes_service_account_v1.aws_load_balancer_controller.metadata[0].name
      }
      region = data.aws_region.current.name
      vpcId  = var.vpc_id
    })
  ]

  # Wait for the deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = var.helm_timeout

  depends_on = [
    kubernetes_service_account_v1.aws_load_balancer_controller,
    aws_iam_role_policy_attachment.aws_load_balancer_controller
  ]
}
