# CloudFront Module - Main Configuration

# CloudFront Distribution for Web Server (i-c)
resource "aws_cloudfront_distribution" "web" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Kishax Web Application Distribution"
  default_root_object = "index.html"
  price_class         = "PriceClass_200"  # Asia, Europe, US (exclude South America, Australia)

  aliases = [var.web_domain_name]

  origin {
    domain_name = var.web_server_public_ip
    origin_id   = "kishax-web-ec2"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # EC2 → HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "kishax-web-ec2"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Referer"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600   # 1 hour
    max_ttl                = 86400  # 24 hours
    compress               = true
  }

  # Cache behavior for static assets
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "kishax-web-ec2"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400   # 24 hours
    max_ttl                = 604800  # 7 days
    compress               = true
  }

  # SSL Certificate
  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Geo Restriction (optional)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Custom error responses
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 500
    response_code      = 500
    response_page_path = "/500.html"
  }

  tags = {
    Name = "kishax-${var.environment}-web-cdn"
  }
}

# WAF Web ACL for CloudFront (optional but recommended)
# resource "aws_wafv2_web_acl" "cloudfront" {
#   name  = "kishax-${var.environment}-cloudfront-waf"
#   scope = "CLOUDFRONT"
#
#   default_action {
#     allow {}
#   }
#
#   rule {
#     name     = "RateLimitRule"
#     priority = 1
#
#     action {
#       block {}
#     }
#
#     statement {
#       rate_based_statement {
#         limit              = 2000
#         aggregate_key_type = "IP"
#       }
#     }
#
#     visibility_config {
#       cloudwatch_metrics_enabled = true
#       metric_name                = "RateLimitRule"
#       sampled_requests_enabled   = true
#     }
#   }
#
#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "kishax-cloudfront-waf"
#     sampled_requests_enabled   = true
#   }
#
#   tags = {
#     Name = "kishax-${var.environment}-cloudfront-waf"
#   }
# }

# # Associate WAF with CloudFront
# resource "aws_wafv2_web_acl_association" "cloudfront" {
#   resource_arn = aws_cloudfront_distribution.web.arn
#   web_acl_arn  = aws_wafv2_web_acl.cloudfront.arn
# }
