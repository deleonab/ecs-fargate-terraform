resource "aws_ecs_service" "devopsuncut_sv" {
  name            = "devops-uncut-service"
  cluster         = aws_ecs_cluster.devopsuncut-ecs-cluster.id
  task_definition = aws_ecs_task_definition.devopsuncut_td.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_tasks2.id]
    subnets         = aws_subnet.private.*.id
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs-fargate-TG.arn
    container_name   = "devops-uncut-webpage"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.https_forward]
}
