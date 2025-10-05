[
  {
    "name": "${container_name}",
    "image": "${ecr_app_image}",
    "essential": true,
    "memory": ${memory_limit},
    "cpu": ${cpu_limit},
    "portMappings": [
        {
            "containerPort": ${container_port},
            "protocol": "tcp"
        }
    ],
    "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
              "awslogs-group": "${log_group}",
              "awslogs-region": "${aws_region}",
              "awslogs-stream-prefix": "${container_name}"
          }
    }
  }
]

