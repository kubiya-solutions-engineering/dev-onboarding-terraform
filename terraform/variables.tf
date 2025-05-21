# Required Core Configuration
variable "teammate_name" {
  description = "Name of your Developer Onboarding teammate (e.g., 'developer-onboarder'). Used to identify the teammate in logs and notifications."
  type        = string
  default     = "developer-onboarder"
}

# Access Control
variable "kubiya_groups_allowed_groups" {
  description = "Groups allowed to interact with the teammate (e.g., ['Admin', 'Users'])."
  type        = list(string)
  default     = ["Admin", "Users"]
}

# Kubiya Runner Configuration
variable "kubiya_runner" {
  description = "Runner to use for the teammate. Change only if using custom runners."
  type        = string
}

variable "debug_mode" {
  description = "Debug mode allows you to see more detailed information and outputs during runtime (shows all outputs and logs when conversing with the teammate)"
  type        = bool
  default     = true
}

variable "gh_org" {
  description = "GitHub organization name"
  type        = string
  sensitive   = true
}

# AWS Configuration
variable "aws_backend_group_name" {
  description = "AWS IAM group name for backend developers"
  type        = string
  default     = "k8s-dev"
}

# GitHub Team Configuration
variable "gh_frontend_team" {
  description = "GitHub team name for frontend developers"
  type        = string
  default     = "Frontend"
}

variable "gh_backend_team" {
  description = "GitHub team name for backend developers"
  type        = string
  default     = "Backend"
}

variable "approvers_slack_channel" {
  description = "Slack channel for onboarding approvals"
  type        = string
  default     = "#onboarding-approvals"
}

variable "approves_group_name" {
  description = "Group name for approvers"
  type        = string
  default     = "Approvers"
}

variable "aws_integration_name" {
  description = "AWS integration name"
  type        = string
}

