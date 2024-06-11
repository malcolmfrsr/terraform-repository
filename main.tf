terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "mf-website" {
  source = "./modules/infrastructure"

  bucket_name      = "mf-webcontent"
  error_page       = "error.html"
  start_page       = "index.html"
  start_page_dir   = "website/index.html"
  origin_access_id = "origin-access-identity/cloudfront/E1UH4UX6RASB3U"
  environment      = "production"
}
