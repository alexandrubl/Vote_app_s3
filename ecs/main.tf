terraform {
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.9"
    }
  }
  backend "s3" {}
}

provider aws {
    profile = "default"
    region  = "us-east-1"
}

data "terraform_remote_state" "env_state" {
  backend = "s3"
  config  = {
      bucket="my-state14"
      key="dev/env.tfstate"
      region="us-east-1"
      profile="default"
  }
}
#===== IAM role =====

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "${var.app_name}-execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags = {
    Name        = "${var.app_name}-iam-role"
    Environment = var.app_environment
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_security_group" "service_security_group" {
  vpc_id = data.terraform_remote_state.env_state.outputs.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [data.terraform_remote_state.env_state.outputs.lb_sg]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.app_name}-service-sg"
    Environment = var.app_environment
  }
}

resource "aws_ecs_task_definition" "aws-ecs-task" {
    family = "${var.app_name}-task"
  
    container_definitions = <<DEFINITION
    [
      {
        "name": "${var.app_name}-${var.app_environment}-container",
        "image": "${data.terraform_remote_state.env_state.outputs.ecr_uri}:latest",
        "entryPoint": [],
        "essential": true,
        "logConfiguration": {
          "logDriver": "awslogs",
          "options": {
            "awslogs-group": "${data.terraform_remote_state.env_state.outputs.cloudwatch_log_group}",
            "awslogs-region": "${var.aws_region}",
            "awslogs-stream-prefix": "${var.app_name}-${var.app_environment}"
          }
        },
        "portMappings": [
          {
            "containerPort": 80,
            "hostPort": 80
          }
        ],
        "cpu": 512,
        "memory": 1024,
        "networkMode": "awsvpc"
      }
    ]
    DEFINITION
  
    requires_compatibilities = ["FARGATE"]
    network_mode             = "awsvpc"
    memory                   = "1024"
    cpu                      = "512"
    execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
    task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  
    tags = {
      Name        = "${var.app_name}-ecs-td"
      Environment = var.app_environment
    }
  }
  
  data "aws_ecs_task_definition" "main" {
    task_definition = aws_ecs_task_definition.aws-ecs-task.family
  }
  
  resource "aws_ecs_service" "aws-ecs-service" {
    name                 = "${var.app_name}-${var.app_environment}-ecs-service"
    cluster              = data.terraform_remote_state.env_state.outputs.ecs_cluster_id
    task_definition      = "${aws_ecs_task_definition.aws-ecs-task.family}:${max(aws_ecs_task_definition.aws-ecs-task.revision, data.aws_ecs_task_definition.main.revision)}"
    launch_type          = "FARGATE"
    scheduling_strategy  = "REPLICA"
    desired_count        = 1
    force_new_deployment = true
  
    network_configuration {
      subnets          = data.terraform_remote_state.env_state.outputs.public_subnet
      assign_public_ip = true
      security_groups = [
        aws_security_group.service_security_group.id,
        data.terraform_remote_state.env_state.outputs.lb_sg
      ]
    }
  
    load_balancer {
      target_group_arn = data.terraform_remote_state.env_state.outputs.lb_tg
      container_name   = "${var.app_name}-${var.app_environment}-container"
      container_port   = 80
    }
  
  #  depends_on = data.terraform_remote_state.env_state.outputs.alb_listener
  }

  #===== ASG =====
  
  resource "aws_appautoscaling_target" "ecs_target" {
    max_capacity       = 2
    min_capacity       = 1
    resource_id        = "service/${data.terraform_remote_state.env_state.outputs.ecs_cluster_name}/${aws_ecs_service.aws-ecs-service.name}"
    scalable_dimension = "ecs:service:DesiredCount"
    service_namespace  = "ecs"
  }
  
  resource "aws_appautoscaling_policy" "ecs_policy_memory" {
    name               = "${var.app_name}-${var.app_environment}-memory-autoscaling"
    policy_type        = "TargetTrackingScaling"
    resource_id        = aws_appautoscaling_target.ecs_target.resource_id
    scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
    service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  
    target_tracking_scaling_policy_configuration {
      predefined_metric_specification {
        predefined_metric_type = "ECSServiceAverageMemoryUtilization"
      }
  
      target_value = 80
    }
  }
  
  resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
    name               = "${var.app_name}-${var.app_environment}-cpu-autoscaling"
    policy_type        = "TargetTrackingScaling"
    resource_id        = aws_appautoscaling_target.ecs_target.resource_id
    scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
    service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  
    target_tracking_scaling_policy_configuration {
      predefined_metric_specification {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
  
      target_value = 80
    }
  }
