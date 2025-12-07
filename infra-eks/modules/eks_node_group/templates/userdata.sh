#!/bin/bash
set -o xtrace

# Bootstrap EKS node
/etc/eks/bootstrap.sh ${cluster_name} \
  --b64-cluster-ca '${cluster_ca_data}' \
  --apiserver-endpoint '${cluster_endpoint}'

# Enable CloudWatch logs
yum install -y amazon-cloudwatch-agent

# Install SSM agent (for Systems Manager access)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

%{ if enable_spot_drainer }
# Install AWS Node Termination Handler for Spot instances
kubectl apply -f https://github.com/aws/aws-node-termination-handler/releases/download/v1.19.0/all-resources.yaml
%{ endif }
