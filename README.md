# AWS Elastic Container Service (ECS)

AWS ECS is a fully managed container orchestration service that allows to run, stop, and manage containers on a ECS Cluster. It is an abstraction of the underlying infrastructure, allowing developers to focus on application development. The key benefits of ECS are:

- Automatic provisioning and scaling of resources (together with autoscaling-groups)
- Traffic load balancing (together with ELB)
- Resource optimisation
  - specially useful on high-low system services demand transition
  - doable thanks to the integration with other AWS services such as ELB
- Portability e.g., avoid configuration drift between dev/prod environments
- Cost-effectiveness

## Key Concepts

- **ECS Task Definition**: configuration and deployment blueprint for _containers_ (i.e., _tasks_). It includes container image definition, CPU and memory limits, networking settings such as container linking to other containers (e.g., DB container), and environment variables (e.g., DB access credentials). An ECS task can be run in a standalone way (e.g., as a batch job or a short-lived container) or as part of an _ECS Service_. ECS tasks are defined by developers.

- **ECS Service**: defines how many copies of a container definition should run on a given _ECS Cluster_. Hence, the _ECS Control Plane_ knows how to scale containers. Furthermore, an ECS service can be associated with an _AWS Elastic Load Balancer (ELB)_ for even distribution of traffic among running containers. ECS services are defined by developers.

- **ECS Agent**: ensures that the containers hosted on an _EC2 Instance_ run correctly and efficiently. It reports all containers' health to _ECS Control Plane_ and executes the commands ordered by the latter e.g., start or stop a container. There must be an EC2 agent running in each _EC2 Instance_. ECS agents can be customised by developers, but AWS offers some [ECS-optimised AMIs](http://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html) that include a standard ECS agent.

- **ECS Control Plane**: central container coordination component on an _EC2 Cluster_. It ensures the wellbeing of the cluster, taking decisions such as running containers on available EC2 instances or scaling up/down containers based on the health status provided by the _ECS Agents_ included at the cluster. When _Auto Scaling Groups_ and/or _ECS Capacity Providers_ are provided, the ECS control plane can also scale _EC2 Instances_. ECS Control Plane is the backbone of ECS and implemented by AWS.

- **ECS Cluster**: composes a collection of related _EC2 Instances_ (i.e., the computing resources) registered with the _ECS Control Plane_. An EC2 cluster is managed at the infrastructure level, often using _Auto Scaling Groups_ and/or _ECS Capacity Providers_. Moreover, an EC2 cluster can provide some logical separation based on a particular purpose such as dev/prod environments, thus preventing issues during system execution. ECS clusters are defined by developers.

> [!NOTE]
> The sources of the contents of this section are:
>
> - [The Ultimate Beginner's Guide to AWS ECS](https://blog.awsfundamentals.com/aws-ecs-beginner-guide)
> - Section 8: Docker on AWS using ECS and ECR - AWS Infrastructure as Code With Terraform Course by Edward Viaene
> - ChatGPT

---

## TODO
- Configure EC2 instance auto-scaling
- How to enable EC2 instances and containers hand-by-hand auto-scaling?
