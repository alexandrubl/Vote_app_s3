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


# =====Create instance SG=====

resource "aws_security_group" "InstanceSG" {
    name = "InstanceSG"
    vpc_id      = aws_vpc.VPC.id
    ingress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# =====Create Webserver1========
resource "aws_instance" "DockerServer" { 
  ami                         = "ami-0c4f7023847b90238"
  instance_type               = "t2.micro"
  key_name                    = "alex_keys"
  subnet_id                   = aws_subnet.subnets.*.id [0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.InstanceSG.id]
  user_data = filebase64("${path.module}/configuration.sh")

  tags                        = {
    Name                      = "DockerServer"
  }
}
