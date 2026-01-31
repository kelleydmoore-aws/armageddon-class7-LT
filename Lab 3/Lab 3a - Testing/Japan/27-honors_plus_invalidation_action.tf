# ############################################
# # Lab 2B-Honors+ - Optional invalidation action (run on demand)
# ############################################

# # Explanation: This is bos’s “break glass” lever — use it sparingly or the bill will bite.
# # No native Terraform resource exists for CloudFront invalidations, so we use null_resource + local-exec
# # to call the AWS CLI. Run this manually via: terraform apply -target=null_resource.bos_invalidate_index01
# resource "null_resource" "bos_invalidate_index01" {
#   # Optional: Trigger only when you want (e.g., change this value or add depends_on = [some_file_change])
#   triggers = {
#     always_run = timestamp() # Forces re-run every apply (remove/comment for on-demand only)
#     # OR: paths_hash = filemd5("path/to/your/index.html")  # Re-run if file changes
#   }

#   provisioner "local-exec" {
#     command = <<EOT
#       aws cloudfront create-invalidation \
#         --distribution-id ${aws_cloudfront_distribution.bos_cf01.id} \
#         --paths "/static/index.html" \
#         --no-cli-pager
#     EOT

#     # Optional: If your AWS CLI is v2.11+ and you want to wait for completion:
#     # command = "... --wait"  # But --wait is not standard; use a loop or separate step if needed

#     interpreter = ["/bin/bash", "-c"]
#   }

#   # Optional: Add depends_on if this should run after something (e.g., S3 upload)
#   # depends_on = [aws_s3_object.index_html]
# }

