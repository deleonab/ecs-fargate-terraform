Plan for today
Deploy a web application as a container in an ECS Cluster

Prerequisites
1. Remote backend to store our statefiles should already be created in our AWS account
Make sure you have already setup up your s3 backend in your AWS account.

Our bucket we have called: devops-uncut-remote-backend
Our DynamoDB table we called: devops-uncut-terraform-locking

2. A docker image that contains our application in Dockerhub


STEP 1. Create Network Infrastructure
Create VPC
Create 2 Public Subnets in 2 AZ's
Create 2 Private Subnets in 2 AZ's
Create Internet Gateway for public subnets 
Create NAT Gateway for private subnets
Create route tables, routes and route table associations

STEP2
Create Loadbalancer, listener and Target group
The listener will forward http traffic on port 80 coming from the Load Balancer to the Target Group


STEP 3

Create ECS cluster
Create Task definition
Create Service to launch our tasks

STEP 4
Access our application using the Load Balancer DNS name




### provider.tf

### Configure the AWS Provider
```
provider "aws" {
  region = var.region
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket         = "devops-uncut-remote-backend"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "devops-uncut-terraform-locking"
    encrypt        = true
  }
}
```

### variables.tf
```
variable "region" {
  type = string
}
variable "subnet_count" {
  type = number
}
variable "vpc_cidr" {
  type = string
}
```


### terraform.tfvars
```
region = "us-east-1"
subnet_count = 2
vpc_cidr = "10.0.0.0/16"

```
### security.tf

We shall create a security group for our load balancer to allow port 80 traffic and one for our tasks to allow port 80 traffic traffic from the load balancer security group.
```
resource "aws_security_group" "lb2" {
  name        = "lb-sg2"
  vpc_id      = aws_vpc.main.id
  description = "controls access to the Application Load Balancer (ALB)"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks2" {
  name        = "ecs-tasks-sg2"
  description = "allow inbound access from the ALB only"
  vpc_id      = aws_vpc.main.id
  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb2.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```



### networking.tf
### Next, we shall set up the networking
We shall create A VPC, 2 public subnets and 2 private subnets in 2 availability zones for high availability and fault tolerance.
Our plan is to create our public facing load balancer in the public subnet and our ECS cluster in the private subnet.

### Declare the availability zone data source
```
data "aws_availability_zones" "available" {
  state = "available"
}
```
### Create the VPC
```
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "main_vpc"
  }
}
```
### public subnet
We use the count meta argument to dynamically generate the number of subnets that we need.
2 in this case so we shall set var.subnet_count = 3 in our tfvars file.


```
### Create the public subnet
resource "aws_subnet" "public" {
  count = var.subnet_count  
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet-${count.index}"
  }
}

### Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main_igw"
  }
}

### Public route table

resource "aws_route_table" "rtb-public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public-RT"
  }
}
```
We use the count meta argument to dynamically retrieve the id’s of our public subnet that were dynamically generated.
```
resource "aws_route" "rtb-public-route" {
  route_table_id         = aws_route_table.rtb-public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "pub-rtb-asoc" {
  count = var.subnet_count
  subnet_id   = aws_subnet.public[count.index].id
  route_table_id  = aws_route_table.rtb-public.id
}


Let’s create 2 private subnets. We shall once again use the count meta argument to dynamically create 2 private subnets.
We need to create a NAT gateway for our private subnet and an elastic ip to allocate to our NAY Gateway.
##################################################

### Create the private subnet

resource "aws_subnet" "private" {
  count = var.subnet_count  
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + 2)

  tags = {
    Name = "private_subnet-${count.index}"
  }
}
resource "aws_eip" "eip" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "gw NAT"
  }
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}




### Private route table

resource "aws_route_table" "rtb-private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Public-RT"
  }
}
resource "aws_route" "rtb-private-route" {
  route_table_id         = aws_route_table.rtb-private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.ngw.id
}

resource "aws_route_table_association" "priv-rtb-asoc" {
  count = var.subnet_count
  subnet_id   = aws_subnet.private[count.index].id
  route_table_id  = aws_route_table.rtb-private.id
}


```

### load_balancer.tf
Now that the Networking is complete, we can now begin with creating our Application Load Balancer, listener and Target Group.

The listener will forward http traffic to the registered target group.
We shall create it in the public subnets and its security group will allow traffic from port 80.
```
resource "aws_lb" "cluster_lb" {
  name               = "cluster-alb"
  subnets            = aws_subnet.public[*].id
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb2.id]

  tags = {
    Application = "devops-uncut-webpage"
  }
}

resource "aws_lb_listener" "https_forward" {
  load_balancer_arn = aws_lb.cluster_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs-fargate-TG.arn
  }
}

resource "aws_lb_target_group" "ecs-fargate-TG" {
  name        = "ecs-fargate-TG"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "90"
    protocol            = "HTTP"
    matcher             = "200-299"
    timeout             = "20"
    path                = "/"
    unhealthy_threshold = "2"
  }
}


### output.tf
Let’s output the load balancers dns name for use later on
output "load_balancer_ip" {
  value = aws_lb.cluster_lb.dns_name
}



### iam_role.tf
Now, we shall create the iam roles needed by our tasks.	
We shall use a datasource to retrieve the policy which will be attached to our role.

data "aws_iam_policy_document" "ecs_task_execution_role" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



### cluster.tf 
Let’s create our ECS Cluster first and the task definition after.
resource "aws_ecs_cluster" "devopsuncut-ecs-cluster" {
  name = "devopsuncut-ecs-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}



### tasks.tf
Please note that we already have a docker image that we created in dockerhub called:
 deleonabowu/devops-uncut-webpage:latest"

Feel free to use this or use your own image from your repository. 

resource "aws_ecs_task_definition" "devopsuncut_td" {
  family                   = "devops-uncut-webpage"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 2048
  memory                   = 4096

  container_definitions = <<DEFINITION
[
  {
    "image": "deleonabowu/devops-uncut-webpage:latest",
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

```
We shall add another variable called app_count which will hold the number of tasks that we want for our service
### variables.tf   (updated with app_count)
```
variable "region" {
  type = string
}
variable "subnet_count" {
  type = number
}
variable "vpc_cidr" {
  type = string
}
variable "app_count" {
  type = number
}
#terraform.tfvars   (updated with app_count)
region = "us-east-1"
subnet_count = 2
vpc_cidr = "10.0.0.0/16"
app_count = 2



### service.tf
Let’s create a service that will launch our tasks using the task definition. Here we shall define our networking and load balancer 

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
```

Let’s go on to create our infrastructure and view it in our browser using the load balancers dns name.
The load balancer will balance traffic between our 2 or more tasks which are instances ofour web page.

Run the following commands
```
terraform init
 terraform validate
terraform plan
terraform apply -auto-approve	
```
- Our output will print out out load balancers dns name. Copy this and run in your browser window.

- Look in your terminal for the output and copy the loadbalancer dns name.

- We shall be able to view our website through the load balancers dns name.

-----------YOU HAVE COMPLETED THE TASK HERE------------


Now let’s take this further by using a custom domain name rather the load balancers dns name to view our webpage.

We shall use route53 for this. 
Our domain name in nollywoodauditions.com
- Please use yours for this. For this to work, you must update the dns entries generated by AWS with your domain name company.

- The changes may also take as much as 48 hours to propagate.
Please be aware that you may incure substantial costs if your infrastructure is running in AWS for this amount of time.

- We shall create a route 53 zone and then a route53 A record to forward traffic to our load balancer.
```
# route53.tf
resource "aws_route53_zone" "nollywood" {
  name = "nollywoodauditions.com"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.nollywood.zone_id
  name    = "nollywoodauditions.com"
  type    = "A"

  alias {
    name                   = aws_lb.cluster_lb.dns_name
    zone_id                = aws_lb.cluster_lb.zone_id
    evaluate_target_health = true
  }
}
```

Run the following commands
```
terraform init
 terraform validate
terraform plan
terraform apply -auto-approve	
```
### Go back to the browser and visit http://nollywoodauditions.com

We should see our web page in the browser.

You have just deployed an application into an ECS cluster running on Fargate, installed a load balancer and pointed a custom domain to it.

You rock!