resource "appwrite_project" "this" {
  id              = var.project_id
  organization_id = var.organization_id
  name            = var.project_name
  region          = var.region

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_tablesdb" "primary" {
  id         = var.database_id
  project_id = var.project_id
  name       = var.database_name
  enabled    = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_site" "landing" {
  id                      = var.site.id
  project_id              = var.project_id
  name                    = var.site.name
  framework               = var.site.framework
  adapter                 = var.site.adapter
  build_runtime           = var.site.build_runtime
  install_command         = var.site.install_command
  build_command           = var.site.build_command
  start_command           = var.site.start_command
  output_directory        = var.site.output_directory
  fallback_file           = var.site.fallback_file
  installation_id         = var.site.installation_id
  provider_repository_id  = var.site.provider_repository_id
  provider_branch         = var.site.provider_branch
  provider_root_directory = var.site.provider_root_directory
  provider_silent_mode    = var.site.provider_silent_mode
  build_specification     = var.site.build_specification
  runtime_specification   = var.site.runtime_specification
  deployment_retention    = var.site.deployment_retention
  timeout                 = var.site.timeout
  logging                 = var.site.logging
  enabled                 = var.site.enabled

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_site_variable" "landing" {
  for_each   = var.site_variables
  project_id = var.project_id
  site_id    = appwrite_site.landing.id
  key        = each.key
  value      = each.value.value
  secret     = each.value.secret

  lifecycle {
    prevent_destroy = true
  }
}
