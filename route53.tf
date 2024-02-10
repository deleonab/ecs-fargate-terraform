resource "aws_route53_zone" "nollywood" {
  name = "nollywoodauditions.com"
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.nollywood.zone_id
  name    = "nollywoodauditions.com"
  type    = "A"

  alias {
    name                   = aws_lb.cluster_lb2.dns_name
    zone_id                = aws_lb.cluster_lb2.zone_id
    evaluate_target_health = true
  }
}