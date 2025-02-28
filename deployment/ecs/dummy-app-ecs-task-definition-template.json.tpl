[
  {
    "name": "${CONTAINER_NAME}",
    "image": "${ECR_APP_IMAGE}",
    "essential": true,
    "memory": 256,
    "cpu": 256,
    "portMappings": [
        {
            "containerPort": ${CONTAINER_PORT},
            "hostPort": 3000
        }
    ]
  }
]

