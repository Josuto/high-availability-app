[
  {
    "name": "${container_name}",
    "image": "${ecr_app_image}",
    "essential": true,
    "memory": 256,
    "cpu": 256,
    "portMappings": [
        {
            "containerPort": ${container_port},
            "hostPort": 0
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

