# ############################################
# # ACM Certificate (TLS) for app.chewbacca-growl.com
# ############################################

# Explanation: TLS is the diplomatic passport — browsers trust you, and Chewbacca stops growling at plaintext.
resource "aws_acm_certificate" "gru_acm_cert01" {
  domain_name               = local.gru_fqdn
  subject_alternative_names = [var.domain_name]
  validation_method         = var.certificate_validation_method

  # TODO: students can add subject_alternative_names like var.domain_name if desired

  tags = {
    Name = "${var.project_name}-acm-cert01"
  }
}

# # Explanation: DNS validation records are the “prove you own the planet” ritual — Route53 makes this elegant.
# # TODO: students implement aws_route53_record(s) if they manage DNS in Route53.
# # resource "aws_route53_record" "chewbacca_acm_validation" { ... }

# Explanation: Once validated, ACM becomes the “green checkmark” — until then, ALB HTTPS won’t work.
resource "aws_acm_certificate_validation" "gru_acm_validation01" {
  certificate_arn = aws_acm_certificate.gru_acm_cert01.arn

  # # TODO: if using DNS validation, students must pass validation_record_fqdns
  # validation_record_fqdns = [aws_route53_record.gru_acm_validation_records01.fqdn]

  #adding from the template resource below as test
  validation_record_fqdns = [
    for r in aws_route53_record.gru_acm_validation01_records01 : r.fqdn
  ]

  timeouts {
    create = "30m" # optional: give more time if propagation is slow
  }
}

# # # Explanation: This ties the “proof record” back to ACM—Chewbacca gets his green checkmark for TLS.
# # resource "aws_acm_certificate_validation" "gru_acm_validation01_dns_bonus" {
# #   count = var.certificate_validation_method == "DNS" ? 1 : 0

# #   certificate_arn = aws_acm_certificate.gru_acm_cert01.arn

# #   validation_record_fqdns = [
# #     for r in aws_route53_record.gru_acm_validation_records01 : r.fqdn
# #   ]

# #   timeouts {
# #     create = "30m"  # optional: give more time if propagation is slow
# #   }
# # }