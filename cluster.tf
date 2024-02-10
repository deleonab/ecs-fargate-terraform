resource "aws_ecs_cluster" "devopsuncut-ecs-cluster" {
  name = "devopsuncut-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
