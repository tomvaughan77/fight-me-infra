variable "github_token" {
  description = "GitHub access token"
  default     = ""
}

variable "github_owner" {
  description = "GitHub organization or username that owns the repository"
  default     = ""
}

variable "github_repository" {
  description = "GitHub repository containing the NextJS app"
  default     = ""
}

variable "amplify_app_name" {
  description = "The name of the Amplify app"
  default     = ""
}
