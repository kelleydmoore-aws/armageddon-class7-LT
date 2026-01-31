# ############################################
# # Hosted Zone (optional creation)
# ############################################

# # Explanation: A hosted zone is like claiming Kashyyyk in DNS—names here become law across the galaxy.
# resource "aws_route53_zone" "edo_zone01" {
#   count = var.manage_route53_in_terraform ? 1 : 0

#   name = local.edo_zone_name

#   tags = {
#     Name = "${var.project_name}-zone01"
#   }
# }

############################################
# Route53: Zone Apex (root domain) -> ALB
############################################

# Explanation: The zone apex is the throne room—chewbacca-growl.com itself should lead to the ALB.
# resource "aws_route53_record" "edo_apex_alias01" {
#   zone_id = local.edo_zone_id
#   name    = var.domain_name
#   type    = "A"

#   alias {
#     name                   = aws_lb.edo_alb01.dns_name
#     zone_id                = aws_lb.edo_alb01.zone_id
#     evaluate_target_health = true
#   }
# }

# # App prefix mapped to ALB
# resource "aws_route53_record" "edo_app_alias01" {
#   zone_id = local.edo_zone_id
#   name    = local.edo_app_fqdn
#   type    = "A"

#   alias {
#     name                   = aws_lb.edo_alb01.dns_name
#     zone_id                = aws_lb.edo_alb01.zone_id
#     evaluate_target_health = true
#   }
# }
