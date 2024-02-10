resource "aws_ecs_task_definition" "devopsuncut_td" {
  family                   = "devops-uncut-webpage"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 2048
  memory                   = 4096

  container_definitions = <<DEFINITION
[
  {
    "image": "deleonabowu/javaapp:latest",
    "cpu": 2048,
    "memory": 4096,
    "name": "devops-uncut-webpage",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
DEFINITION
}
