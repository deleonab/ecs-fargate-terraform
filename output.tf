output "load_balancer_ip" {
  value = aws_lb.cluster_lb2.dns_name
}
