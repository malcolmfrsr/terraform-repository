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


#####################################################################
###################### bucket infrastructure ########################
#####################################################################
resource "aws_s3_bucket" "web-repository" {
  bucket = var.bucket_name

  tags = {
    Name        = "mf-webcontent"
    Environment = "test-account"
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  depends_on = [aws_s3_bucket.web-repository]

  bucket = aws_s3_bucket.web-repository.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {

  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity E1UH4UX6RASB3U"] 
    }

    actions = [
      "s3:GetObject"
    ]

    sid = "PublicReadGetObject"

    resources = [aws_s3_bucket.web-repository.arn,
      "${aws_s3_bucket.web-repository.arn}/*"
    ]
  }
}

resource "aws_s3_bucket_public_access_block" "web-repository" {
  bucket = aws_s3_bucket.web-repository.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#####################################################################
######################### website content ###########################
#####################################################################
# Configure 
resource "aws_s3_bucket_website_configuration" "mf_s3_website_configuration" {
  bucket = aws_s3_bucket.web-repository.id

  index_document {
    suffix = var.start_page
  }

  error_document {
    key = var.start_page
  }
}

resource "aws_s3_object" "webindex" {
  bucket = aws_s3_bucket.web-repository.id
  key    = var.start_page
  source = var.start_page_dir

  content_type = "text/html"
  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5(var.start_page_dir)
}

#####################################################################
##################### cloudfront distribution #######################
#####################################################################
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "s3_distribution_access_control"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    origin_id   = aws_s3_bucket.web-repository.id
    domain_name = aws_s3_bucket.web-repository.bucket_regional_domain_name
    s3_origin_config {
      origin_access_identity = "origin-access-identity/cloudfront/E1UH4UX6RASB3U"
    }
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = var.start_page

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.web-repository.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = aws_s3_bucket.web-repository.id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.web-repository.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}