#! /bin/bash
sudo apt update
sudo apt install -y unzip
sudo apt install -y git
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt-cache policy docker-ce
sudo apt install -y docker-ce
sudo usermod -aG docker ubuntu
sudo chown ubuntu:docker /var/run/docker.sock
pushd /home/ubuntu
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
sudo aws configure set aws_access_key_id AKIAZEJ6WZGMHVFR4ALI --profile default
sudo aws configure set aws_secret_access_key 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
sudo aws configure set default.region us-east-1
git clone --branch dev https://github.com/alexandrublg/web_app.git
cd web_app
docker build -t webserver:latest . --no-cache
sudo aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/a1a0n4j9
docker tag webserver:latest public.ecr.aws/a1a0n4j9/webserver-ecr:latest
docker push public.ecr.aws/a1a0n4j9/webserver-ecr:latest
popd