# Route53 Module - Main Configuration

# MC Server A Record (初期値のみ、後はUser Dataで自動更新)
resource "aws_route53_record" "mc_server" {
  zone_id = var.route53_zone_id
  name    = var.mc_domain_name
  type    = "A"
  ttl     = 60

  records = [var.mc_server_elastic_ip]

  lifecycle {
    ignore_changes = [records]  # User Dataで更新されるため
  }
}

# Web Application Alias Record (CloudFront経由)
resource "aws_route53_record" "web" {
  count           = var.web_domain_name != "" ? 1 : 0
  zone_id         = var.route53_zone_id
  name            = var.web_domain_name
  type            = "A"
  allow_overwrite = true  # 既存レコードを上書き

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_zone_id
    evaluate_target_health = false
  }
}

# Terraria Server A Record
resource "aws_route53_record" "terraria_server" {
  count   = var.terraria_domain_name != "" ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.terraria_domain_name
  type    = "A"
  ttl     = 60

  records = [var.terraria_server_elastic_ip]
}
