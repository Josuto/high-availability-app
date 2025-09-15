#!/bin/bash
echo 'ECS_CLUSTER=ecs-cluster' > /etc/ecs/ecs.config # Make the EC2 instance join the ECS cluster
start ecs # Start the ECS agent on the EC2 instance
