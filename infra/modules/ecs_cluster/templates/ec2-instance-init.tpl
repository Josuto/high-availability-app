#!/bin/bash
set -xe # Enable logging for debugging user data script execution
echo 'ECS_CLUSTER=${ecs_cluster_name}' > /etc/ecs/ecs.config # Make the EC2 instance join the ECS cluster
systemctl enable --now ecs # Start the ECS agent on the EC2 instance
