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
  token = getenv("REPOSITORY_ACCESS_TOKEN")
  owner = getenv("GITHUB_OWNER")
}

resource "aws_amplify_app" "fight_me_frontend_amplify_app" {
  name       = getenv("AMPLIFY_APP_NAME")
  repository = "https://${getenv("github_owner")}.github.io/${getenv("GITHUB_REPOSITORY")}"

  oauth_token = getenv("REPOSITORY_ACCESS_TOKEN")

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
