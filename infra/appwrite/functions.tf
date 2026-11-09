resource "appwrite_function" "existing" {
  for_each                = var.functions
  id                      = each.value.id
  project_id              = var.project.id
  name                    = each.value.name
  runtime                 = each.value.runtime
  entrypoint              = each.value.entrypoint
  commands                = each.value.commands
  execute                 = each.value.execute
  scopes                  = each.value.scopes
  events                  = each.value.events
  installation_id         = each.value.installation_id
  provider_repository_id  = each.value.provider_repository_id
  provider_branch         = each.value.provider_branch
  provider_root_directory = each.value.provider_root_directory
  provider_silent_mode    = false
  build_specification     = "s-2vcpu-2gb"
  runtime_specification   = "s-0.5vcpu-512mb"
  deployment_retention    = 0
  timeout                 = 15
  logging                 = true
  enabled                 = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_function_variable" "existing" {
  for_each         = var.function_variables
  project_id       = var.project.id
  function_id      = appwrite_function.existing[each.value.function_key].id
  key              = each.value.key
  value            = each.value.secret ? null : each.value.value
  value_wo         = each.value.secret ? var.function_secret_values[each.key] : null
  value_wo_version = each.value.secret ? 1 : null
  secret           = each.value.secret

  lifecycle {
    prevent_destroy = true
  }
}

# Existing project keys are imported. The Appwrite API cannot mint a new
# project key through this provider, so new environments require bootstrap.
resource "appwrite_project_key" "existing" {
  for_each        = var.project_keys
  id              = each.value.id
  organization_id = var.organization_id
  project_id      = var.project.id
  name            = each.value.name
  scopes          = each.value.scopes

  lifecycle {
    prevent_destroy = true
  }
}
