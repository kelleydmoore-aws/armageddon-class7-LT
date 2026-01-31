resource "aws_launch_template" "edo_LT" {
  name_prefix   = "${var.project_name}-LT-"
  image_id      = var.ec2_ami_id
  instance_type = var.ec2_instance_type

  # key_name = "MyLinuxbox"   # ← change if you use different key

  vpc_security_group_ids = [aws_security_group.edo_ec2_sg01.id]

  user_data = filebase64("96-1a_user_data.sh") # make sure this file exists!

  iam_instance_profile {
    name = aws_iam_instance_profile.edo_instance_profile01.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-instance"
      Service = "web-app"
      Owner   = "Terraform"
      Project = var.project_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}