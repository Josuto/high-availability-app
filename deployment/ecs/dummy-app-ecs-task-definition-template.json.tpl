[
  {
    "essential": true,
    "memory": 256,
    "name": "${CONTAINER_NAME}",
    "cpu": 256,
    "image": "${ECR_APP_IMAGE}",
    // "workingDirectory": "/app",  # this parameter overrides its counterpart of the Dockerfile. It's commented out since we do not want to do that
    // "command": ["npm", "start"], # this parameter overrides its counterpart of the Dockerfile. It's commented out since we do not want to do that
    "portMappings": [
        {
            "containerPort": "${CONTAINER_PORT}",
            "hostPort": 3000
        }
    ]
  }
]

