# # Provider & Version
# # https://registry.terraform.io/providers/hashicorp/aws/6.17.0/docs

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias = "apnortheast1"
  region = "ap-northeast-1"
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

terraform {
  backend "s3" {
    bucket = "arma-brazil-backend-lt1"
    key    = "01.27.26/terraform.tfstate"
    region = "sa-east-1"
  }
}