#!/bin/bash

###############################################################################
# generate-manifests.sh
#
# This script generates Kubernetes manifests with actual values from Terraform
# remote state, replacing placeholders in the template files.
#
# Usage:
#   ./scripts/generate-manifests.sh [state-bucket-name] [aws-region]
#
# Example:
#   ./scripts/generate-manifests.sh my-terraform-state-bucket eu-west-1
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform state bucket accessible
#   - jq installed (for JSON parsing)
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Parse arguments
STATE_BUCKET="${1:-}"
AWS_REGION="${2:-eu-west-1}"

if [ -z "$STATE_BUCKET" ]; then
    print_error "Usage: $0 <state-bucket-name> [aws-region]"
    echo ""
    echo "Example:"
    echo "  $0 my-terraform-state-bucket eu-west-1"
    exit 1
fi

print_info "Generating Kubernetes manifests from Terraform state..."
print_info "State Bucket: $STATE_BUCKET"
print_info "AWS Region: $AWS_REGION"
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEMPLATES_DIR="$PROJECT_ROOT/k8s-manifests"
OUTPUT_DIR="$PROJECT_ROOT/k8s-manifests-generated"

# Create output directory
mkdir -p "$OUTPUT_DIR"

###############################################################################
# Function to fetch Terraform output from remote state
###############################################################################
get_terraform_output() {
    local state_key=$1
    local output_name=$2

    print_info "Fetching $output_name from $state_key..."

    # Download state file
    local state_file=$(mktemp)
    aws s3 cp "s3://${STATE_BUCKET}/${state_key}" "$state_file" --region "$AWS_REGION" 2>/dev/null || {
        print_error "Failed to download state file: s3://${STATE_BUCKET}/${state_key}"
        print_warn "Make sure the state file exists and you have access to it."
        rm -f "$state_file"
        return 1
    }

    # Extract output value
    local value=$(cat "$state_file" | jq -r ".outputs.${output_name}.value // empty")
    rm -f "$state_file"

    if [ -z "$value" ] || [ "$value" = "null" ]; then
        print_error "Output '$output_name' not found in state: $state_key"
        return 1
    fi

    echo "$value"
}

###############################################################################
# Fetch required values from Terraform state
###############################################################################

print_info "Step 1: Fetching ECR repository URL..."
ECR_REPOSITORY_URL=$(get_terraform_output "deployment/ecr/terraform.tfstate" "ecr_repository_url")
if [ $? -ne 0 ]; then
    print_error "Failed to get ECR repository URL"
    print_warn "Make sure ECR has been deployed: cd infra/deployment/ecr && terraform apply"
    exit 1
fi
print_info "  ECR URL: $ECR_REPOSITORY_URL"
echo ""

print_info "Step 2: Fetching ACM certificate ARN..."
ACM_CERTIFICATE_ARN=$(get_terraform_output "deployment/ssl/terraform.tfstate" "acm_certificate_validation_arn")
if [ $? -ne 0 ]; then
    print_error "Failed to get ACM certificate ARN"
    print_warn "Make sure SSL/ACM has been deployed: cd infra/deployment/ssl && terraform apply"
    exit 1
fi
print_info "  ACM ARN: $ACM_CERTIFICATE_ARN"
echo ""

print_info "Step 3: Fetching EKS cluster name (optional)..."
EKS_CLUSTER_NAME=$(get_terraform_output "deployment-eks/prod/eks_cluster/terraform.tfstate" "cluster_id" 2>/dev/null || echo "")
if [ -z "$EKS_CLUSTER_NAME" ]; then
    print_warn "EKS cluster not deployed yet. Using placeholder for cluster name."
    EKS_CLUSTER_NAME="prod-terraform-course-dummy-nestjs-app-eks-cluster"
else
    print_info "  EKS Cluster: $EKS_CLUSTER_NAME"
fi
echo ""

###############################################################################
# Generate manifests from templates
###############################################################################

print_info "Step 4: Generating manifest files..."
echo ""

# deployment.yaml
print_info "  Generating deployment.yaml..."
sed "s|<ECR_REPOSITORY_URL>|${ECR_REPOSITORY_URL}|g" \
    "$TEMPLATES_DIR/deployment.yaml" > "$OUTPUT_DIR/deployment.yaml"

# service.yaml (no placeholders, just copy)
print_info "  Copying service.yaml..."
cp "$TEMPLATES_DIR/service.yaml" "$OUTPUT_DIR/service.yaml"

# ingress.yaml
print_info "  Generating ingress.yaml..."
sed "s|<ACM_CERTIFICATE_ARN>|${ACM_CERTIFICATE_ARN}|g" \
    "$TEMPLATES_DIR/ingress.yaml" > "$OUTPUT_DIR/ingress.yaml"

# hpa.yaml (no placeholders, just copy)
print_info "  Copying hpa.yaml..."
cp "$TEMPLATES_DIR/hpa.yaml" "$OUTPUT_DIR/hpa.yaml"

echo ""
print_info "✓ Manifest generation complete!"
echo ""

###############################################################################
# Display summary
###############################################################################

cat <<EOF
${GREEN}═══════════════════════════════════════════════════════════════${NC}
  Generated Kubernetes Manifests
${GREEN}═══════════════════════════════════════════════════════════════${NC}

Output Directory: ${OUTPUT_DIR}

Generated Files:
  ✓ deployment.yaml  (ECR URL: ${ECR_REPOSITORY_URL})
  ✓ service.yaml
  ✓ ingress.yaml     (ACM ARN: ${ACM_CERTIFICATE_ARN})
  ✓ hpa.yaml

${GREEN}═══════════════════════════════════════════════════════════════${NC}

Next Steps:

1. Review the generated manifests:
   ${YELLOW}cat ${OUTPUT_DIR}/deployment.yaml${NC}
   ${YELLOW}cat ${OUTPUT_DIR}/ingress.yaml${NC}

2. Ensure EKS cluster is deployed and configured:
   ${YELLOW}cd infra-eks/deployment/app/eks_cluster && terraform apply${NC}
   ${YELLOW}cd ../eks_node_group && terraform apply${NC}

3. Configure kubectl to use the EKS cluster:
   ${YELLOW}aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION}${NC}

4. Install AWS Load Balancer Controller:
   ${YELLOW}# See infra-eks/README.md for detailed instructions${NC}

5. Deploy the application to Kubernetes:
   ${YELLOW}kubectl apply -f ${OUTPUT_DIR}/${NC}

6. Verify the deployment:
   ${YELLOW}kubectl get deployments${NC}
   ${YELLOW}kubectl get services${NC}
   ${YELLOW}kubectl get ingress${NC}
   ${YELLOW}kubectl get hpa${NC}

7. Get the ALB URL:
   ${YELLOW}kubectl get ingress nestjs-app-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'${NC}

${GREEN}═══════════════════════════════════════════════════════════════${NC}
EOF

print_info "Script completed successfully!"
