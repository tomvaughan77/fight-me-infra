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

provider "github" {
  token = var.github_token
  owner = var.github_owner
}

resource "aws_amplify_app" "fight_me_frontend_amplify_app" {
  name       = var.amplify_app_name
  repository = "https://github.com/${var.github_owner}/${var.github_repository}"

  oauth_token = var.github_token

  build_spec = <<EOT
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - pnpm install
    build:
      commands:
        - pnpm run build
  artifacts:
    baseDirectory: .next
    files:
      - '**/*'
  cache:
    paths:
      - node_modules/**/*
      - .pnpm-store/**/*
EOT
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.fight_me_frontend_amplify_app.id
  branch_name = "main"

  build_spec = jsonencode({
    version = "1.0"
    frontend = {
      phases = {
        preBuild = {
          commands = [
            "pnpm install"
          ]
        }
        build = {
          commands = [
            "pnpm run build"
          ]
        }
      }
      artifacts = {
        baseDirectory = ".next"
        files = [
          "**/*"
        ]
      }
      cache = {
        paths = [
          ".next/cache/**/*"
        ]
      }
    }
  })
}
