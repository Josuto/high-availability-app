# IAM Role for EKS Cluster
# Allows EKS to manage AWS resources on your behalf

resource "aws_iam_role" "eks_cluster" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

# Attach required AWS managed policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# Additional policy for encryption if KMS key is provided
resource "aws_iam_role_policy" "eks_encryption" {
  count = var.kms_key_arn != "" ? 1 : 0

  name = "${local.cluster_name}-encryption"
  role = aws_iam_role.eks_cluster.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:CreateGrant"
      ]
      Effect   = "Allow"
      Resource = var.kms_key_arn
    }]
  })
}
