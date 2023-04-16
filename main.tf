terraform {
  backend "s3" {
    bucket         = "fight-me-infra-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_s3_bucket" "fight_me_frontend" {
  bucket = "fight-me-frontend-nextjs-app"
}

resource "aws_s3_bucket_ownership_controls" "fight_me_frontend_ownership_controls" {
  bucket = aws_s3_bucket.fight_me_frontend.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "fight_me_frontend_public_access_block" {
  bucket = aws_s3_bucket.fight_me_frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "fight_me_frontend_acl" {
  bucket = aws_s3_bucket.fight_me_frontend.id
  acl    = "public-read"

  depends_on = [
    aws_s3_bucket_ownership_controls.fight_me_frontend_ownership_controls,
    aws_s3_bucket_public_access_block.fight_me_frontend_public_access_block,
  ]
}

resource "aws_s3_bucket_website_configuration" "fight_me_frontend_website_configuration" {
  bucket = aws_s3_bucket.fight_me_frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_object" "fight_me_frontend_object" {
  key          = "index.html"
  bucket       = aws_s3_bucket.fight_me_frontend.bucket
  source       = ".next"
  acl          = "public-read"
  content_type = "text/html"

  depends_on = [
    aws_s3_bucket_acl.fight_me_frontend_acl,
    aws_s3_bucket_website_configuration.fight_me_frontend_website_configuration,
  ]
}

resource "aws_s3_bucket_policy" "fight_me_frontend_bucket_policy" {
  bucket = aws_s3_bucket.fight_me_frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = [aws_s3_bucket.fight_me_frontend.arn, "${aws_s3_bucket.fight_me_frontend.arn}/*"]
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_acl.fight_me_frontend_acl,
    aws_s3_bucket_website_configuration.fight_me_frontend_website_configuration,
  ]
}
