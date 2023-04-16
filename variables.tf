variable "github_token" {
  description = "GitHub personal access token"
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or username that owns the repository"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository containing the NextJS app"
  type        = string
}

variable "amplify_app_name" {
  description = "The name of the Amplify app"
  type        = string
}
