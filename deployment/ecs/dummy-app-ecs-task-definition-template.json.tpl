[
  {
    "essential": true,
    "memory": 256,
    "name": "${CONTAINER_NAME}",
    "cpu": 256,
    "image": "${ECR_APP_IMAGE}",
    "portMappings": [
        {
            "containerPort": ${CONTAINER_PORT},
            "hostPort": 3000
        }
    ]
  }
]

