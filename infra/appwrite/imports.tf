# Import existing infrastructure into the selected workspace before any apply.
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
