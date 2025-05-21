terraform {
  required_providers {
    kubiya = {
      source = "kubiya-terraform/kubiya"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}


provider "kubiya" {
  // API key is set as an environment variable KUBIYA_API_KEY
}

# Load knowledge sources
data "http" "onboarding_knowledge" {
  url = "https://raw.githubusercontent.com/kubiyabot/terraform-modules/refs/heads/main/jit-permissions-guardians/terraform/knowledge/jit_access.md"
}

# Configure sources
resource "kubiya_source" "enforcer_source" {
  url    = "https://github.com/kubiyabot/community-tools/tree/main/just_in_time_access_proactive"
  runner = var.kubiya_runner
  dynamic_config = jsonencode({
    dd_api_key         = ""
    dd_site            = ""
    idp_provider       = "kubiya"
    okta_base_url      = ""
    okta_client_id     = ""
    okta_private_key   = ""
    okta_token_endpoint = ""
    opa_policy         = "package kubiya.tool_manager\n\n# Default deny all access\ndefault allow = false\n\n# Define list of restricted tools that require special permissions\nrestricted_tools = {\n    \"github_add_user_to_team\",\n    \"github_add_user\",\n    \"iam_create_user\"\n}\n\n# Explicitly allow the request_tool_access feature\nallow {\n    input.tool.name == \"request_tool_access\"\n}\n\n# Allow everyone to run non-restricted tools\nallow {\n    not restricted_tools[input.tool.name]\n}"
    opa_runner_name    = var.kubiya_runner
  })
}

# Configure developer onboarding source
resource "kubiya_source" "developer_onboarding_source" {
  url    = "https://github.com/kubiya-solutions-engineering/developer-onboarding"
}

# Create webhook for developer onboarding requests
resource "kubiya_webhook" "developer_onboarding_webhook" {
  name = "Developer Onboarding Webhook"
  source = "Developer Onboarding"
  prompt = "Sum up this developer onboarding request. Here is all the relevant data (no need to run describe tool).. request_id: {{.event.request_id}}, requested_by: {{.event.user_email}}, requested to run tool {{.event.tool_name}} with parameters {{.event.tool_params}}. requested for team {{.event.team_type}}"
  agent = kubiya_agent.query_assistant.name
  destination = var.approvers_slack_channel
  filter = ""
}

variable "GH_TOKEN" {
  type        = string
  sensitive   = true
  description = "API token for Github authentication"
}

# Create secret using provider
resource "kubiya_secret" "gh_token" {
  name        = "GH_TOKEN"
  value       = var.GH_TOKEN
  description = "Github token for the Developer Onboarding agent"
}

# Configure the Developer Onboarding agent
resource "kubiya_agent" "query_assistant" {
  name         = "developer-onboarder"
  runner       = var.kubiya_runner
  description  = "AI-powered assistant that helps onboard new developers to the team"
  instructions = <<-EOT
Your primary role is to assist with onboarding new developers to the team.

When a user asks to be onboarded to the frontend team:
1. Ask for their email address if not provided
2. Use the github_add_user tool with their email and team_type="frontend"
3. Inform the user that they need to accept the GitHub invitation sent to their email
4. Let them know their onboarding is complete

When a user asks to be onboarded to the backend team:
1. Ask for their email address if not provided
2. Use the github_add_user tool with their email and team_type="backend"
3. Use the iam_create_user tool to create an AWS IAM user for them
4. Inform the user that they need to accept the GitHub invitation sent to their email
5. Let them know their onboarding is complete with both GitHub and AWS access

For any onboarding request:
1. First determine which team the user needs to be onboarded to (frontend or backend)
2. Follow the appropriate onboarding process as outlined above
3. Guide the user through each step of the process
4. If you encounter any issues, explain the problem and suggest next steps

Always be helpful, clear, and concise in your instructions to new team members.
Your goal is to make the onboarding process as smooth as possible for new developers.
EOT
  sources      = [kubiya_source.enforcer_source.name, kubiya_source.developer_onboarding_source.name]
  
  integrations = [var.aws_integration_name, "slack"]

  users  = []
  groups = var.kubiya_groups_allowed_groups

  environment_variables = {
    KUBIYA_TOOL_TIMEOUT = "500"
    AWS_BACKEND_GROUP_NAME = var.aws_backend_group_name
    GH_FRONTEND_TEAM = var.gh_frontend_team
    GH_BACKEND_TEAM = var.gh_backend_team
    GH_ORG = var.gh_org
  }

  secrets = ["GH_TOKEN"]

  is_debug_mode = var.debug_mode
  
  lifecycle {
    ignore_changes = [
      environment_variables
    ]
  }
}

# Set up environment variables including the webhook URL
resource "null_resource" "runner_env_setup" {
  triggers = {
    runner     = var.kubiya_runner
    webhook_id = kubiya_webhook.developer_onboarding_webhook.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -X PUT \
      -H "Authorization: UserKey $KUBIYA_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
        "uuid": "${kubiya_agent.query_assistant.id}",
        "environment_variables": {
          "KUBIYA_TOOL_TIMEOUT": "500",
          "AWS_BACKEND_GROUP_NAME": "${var.aws_backend_group_name}",
          "GH_FRONTEND_TEAM": "${var.gh_frontend_team}",
          "GH_BACKEND_TEAM": "${var.gh_backend_team}",
          "GH_ORG": "${var.gh_org}",
          "REQUEST_ACCESS_WEBHOOK_URL": "${kubiya_webhook.developer_onboarding_webhook.url}"
        }
      }' \
      "https://api.kubiya.ai/api/v1/agents/${kubiya_agent.query_assistant.id}"
    EOT
  }
  
  depends_on = [
    kubiya_webhook.developer_onboarding_webhook
  ]
}

# Output the agent details
output "query_assistant" {
  sensitive = true
  value = {
    name       = kubiya_agent.query_assistant.name
    debug_mode = var.debug_mode
    webhook_url = kubiya_webhook.developer_onboarding_webhook.url
  }
}