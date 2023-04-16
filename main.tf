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
  website {
    index_document = "index.html"
  }
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
  depends_on = [
    aws_s3_bucket_ownership_controls.fight_me_frontend_ownership_controls,
    aws_s3_bucket_public_access_block.fight_me_frontend_public_access_block,
  ]

  bucket = aws_s3_bucket.fight_me_frontend.id
  acl    = "public-read"
}

resource "aws_s3_object" "fight_me_frontend_object" {
  key          = "index.html"
  bucket       = aws_s3_bucket.fight_me_frontend.bucket
  source       = ".next"
  acl          = "public-read"
  content_type = "text/html"
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
}

# provider "github" {
#   token = var.github_token
#   owner = var.github_owner
# }

# resource "aws_amplify_app" "fight_me_frontend_amplify_app" {
#   name       = var.amplify_app_name
#   repository = "https://github.com/${var.github_owner}/${var.github_repository}"

#   access_token = var.github_token

#   enable_auto_branch_creation = true

#   auto_branch_creation_patterns = [
#     "*",
#     "*/**",
#   ]

#   auto_branch_creation_config {
#     enable_auto_build = true
#   }

#   custom_rule {
#     source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|js|png|txt|svg|woff|ttf|map|json)$)([^.]+$)/>"
#     status = "200"
#     target = "/index.html"
#   }

#   build_spec = <<EOT
# version: 1
# frontend:
#   phases:
#     preBuild:
#       commands:
#         - npx pnpm install
#     build:
#       commands:
#         - npx pnpm build
#   artifacts:
#     baseDirectory: .next
#     files:
#       - '**/*'
#   cache:
#     paths:
#       - node_modules/**/*
#       - .pnpm-store/**/*
# EOT
# }

# resource "aws_amplify_branch" "fight_me_frontend_amplify_app_main" {
#   app_id      = aws_amplify_app.fight_me_frontend_amplify_app.id
#   branch_name = "main"
# }

# resource "aws_amplify_webhook" "fight_me_frontend_amplify_app_main_webhook" {
#   app_id      = aws_amplify_app.fight_me_frontend_amplify_app.id
#   branch_name = aws_amplify_branch.fight_me_frontend_amplify_app_main.branch_name
# }
