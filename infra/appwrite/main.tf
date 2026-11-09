provider "appwrite" {
  endpoint        = var.endpoint
  organization_id = var.organization_id
  project_id      = var.project.id
  # APPWRITE_API_KEY and APPWRITE_ORGANIZATION_API_KEY are supplied at runtime.
}

resource "terraform_data" "environment_guard" {
  input = var.environment

  lifecycle {
    precondition {
      condition     = terraform.workspace == var.environment
      error_message = "Select the Terraform workspace that matches the environment var file."
    }
  }
}

module "core" {
  source = "./modules/core"

  organization_id = var.organization_id
  project_id      = var.project.id
  project_name    = var.project.name
  region          = var.project.region
  database_id     = var.database.id
  database_name   = var.database.name
  site            = var.site
  site_variables  = var.site_variables
}
