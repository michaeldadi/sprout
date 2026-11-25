# Import existing infrastructure into the selected workspace before any apply.
# Staging function boundaries were created through the console-authorized API
# because the existing Terraform key cannot delegate their runtime row scopes.
# Keep their resource definitions and subsequent changes in this same state.
import {
  for_each = var.enable_financial_backend && var.environment == "staging" ? { for name, value in local.financial_functions : name => value if contains(["api", "webhooks", "worker", "ai", "dispatcher", "privacy", "privacy-status"], name) } : {}
  to       = appwrite_function.financial[each.key]
  id       = "sprout-${each.key}"
}

import {
  to = module.core.appwrite_project.this
  id = "${var.organization_id}/${var.project.id}"
}

import {
  to = module.core.appwrite_tablesdb.primary
  id = var.database.id
}

import {
  to = module.core.appwrite_site.landing
  id = var.site.id
}

import {
  for_each = var.site_variables
  to       = module.core.appwrite_site_variable.landing[each.key]
  id       = "${var.site.id}/${each.value.id}"
}

import {
  for_each = var.functions
  to       = appwrite_function.existing[each.key]
  id       = each.value.id
}

import {
  for_each = var.function_variables
  to       = appwrite_function_variable.existing[each.key]
  id       = "${var.functions[each.value.function_key].id}/${each.value.id}"
}

import {
  for_each = var.project_keys
  to       = appwrite_project_key.existing[each.key]
  id       = "${var.organization_id}/${var.project.id}/${each.value.id}"
}

# The console-authorized daily backup policy was created after restore proof.
import {
  for_each = var.enable_financial_backend && var.enable_financial_backups && var.environment == "staging" ? toset(["staging"]) : toset([])
  to       = appwrite_backup_policy.financial[0]
  id       = var.financial_backup_policy.id
}
