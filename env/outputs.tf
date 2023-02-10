output "lb_sg" {
    value = aws_security_group.load_balancer_security_group.id
}
output "ecr_uri" {
    value = aws_ecrpublic_repository.aws-ecr.repository_uri
}
output "cloudwatch_log_group" {
    value = aws_cloudwatch_log_group.log-group.id
}
output "ecs_cluster_id" {
    value = aws_ecs_cluster.aws-ecs-cluster.id
}
output "public_subnet" {
    value = aws_subnet.public.*.id
}
output "lb_tg" {
    value =  aws_lb_target_group.target_group.arn
}
output "lb_listener" {
    value = aws_lb_listener.listener.id
}
output "ecs_cluster_name" {
    value = aws_ecs_cluster.aws-ecs-cluster.name
}
output "vpc_id" {
    value = aws_vpc.aws-vpc.id
}
output "alb_listener" {
    value = aws_lb_listener.listener
}


  