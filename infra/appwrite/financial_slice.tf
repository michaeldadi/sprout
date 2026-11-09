locals {
  manual_transactions = var.manual_transactions_enabled ? toset([var.environment]) : toset([])

  transaction_columns = {
    owner_id = { type = "varchar", size = 36, required = true }
    # Appwrite persists the full signed 64-bit bounds regardless of narrower
    # bounds supplied on create. The function enforces JavaScript safe integers.
    amount_minor     = { type = "bigint", min = -9223372036854775808, max = 9223372036854775807, required = true }
    currency         = { type = "varchar", size = 3, required = true }
    type             = { type = "enum", elements = ["expense", "income", "transfer"], required = true }
    category         = { type = "varchar", size = 64, required = true }
    description      = { type = "varchar", size = 512, required = false }
    merchant         = { type = "varchar", size = 128, required = false }
    transaction_date = { type = "varchar", size = 10, required = true }
    source           = { type = "enum", elements = ["manual"], required = true }
    source_id        = { type = "varchar", size = 36, required = true }
    # The function limits versions to signed 32-bit values before incrementing.
    version            = { type = "integer", min = 1, max = 9223372036854775807, required = true }
    modified_at        = { type = "datetime", required = true }
    deleted_at         = { type = "datetime", required = false }
    last_mutation_id   = { type = "varchar", size = 36, required = true }
    last_mutation_hash = { type = "varchar", size = 64, required = true }
  }
}

resource "appwrite_tablesdb_table" "manual_transactions" {
  for_each     = local.manual_transactions
  project_id   = var.project.id
  database_id  = module.core.database_id
  id           = "manual_transactions_v1"
  name         = "Manual transactions"
  row_security = true
  permissions  = []
  enabled      = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_tablesdb_column" "manual_transactions" {
  for_each    = { for key, column in local.transaction_columns : key => column if var.manual_transactions_enabled }
  project_id  = var.project.id
  database_id = module.core.database_id
  table_id    = appwrite_tablesdb_table.manual_transactions[var.environment].id
  key         = each.key
  type        = each.value.type
  size        = try(each.value.size, null)
  elements    = try(each.value.elements, null)
  min         = try(each.value.min, null)
  max         = try(each.value.max, null)
  required    = each.value.required

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_tablesdb_index" "manual_transactions_owner_modified" {
  for_each    = local.manual_transactions
  project_id  = var.project.id
  database_id = module.core.database_id
  table_id    = appwrite_tablesdb_table.manual_transactions[var.environment].id
  key         = "owner_modified"
  type        = "key"
  columns     = [appwrite_tablesdb_column.manual_transactions["owner_id"].key, appwrite_tablesdb_column.manual_transactions["modified_at"].key]
  orders      = ["asc", "asc"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_function" "manual_transactions" {
  for_each   = local.manual_transactions
  id         = "manual-transactions-v1"
  project_id = var.project.id
  name       = "Manual transactions (${var.environment})"
  runtime    = "node-22"
  entrypoint = "index.js"
  commands   = "npm ci --no-audit --no-fund && npm run build"
  execute    = ["users"]
  scopes     = ["rows.read", "rows.write"]
  events     = []
  timeout    = 30
  logging    = false
  enabled    = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_function_variable" "manual_transactions_database" {
  for_each    = local.manual_transactions
  project_id  = var.project.id
  function_id = appwrite_function.manual_transactions[var.environment].id
  key         = "SPROUT_DATABASE_ID"
  value       = module.core.database_id
  secret      = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_function_variable" "manual_transactions_table" {
  for_each    = local.manual_transactions
  project_id  = var.project.id
  function_id = appwrite_function.manual_transactions[var.environment].id
  key         = "SPROUT_TABLE_ID"
  value       = appwrite_tablesdb_table.manual_transactions[var.environment].id
  secret      = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "appwrite_function_deployment" "manual_transactions" {
  for_each    = local.manual_transactions
  project_id  = var.project.id
  function_id = appwrite_function.manual_transactions[var.environment].id
  source_type = "code"
  code_path   = "${path.module}/.artifacts/manual-transactions-v1.tar.gz"
  code_hash   = filesha256("${path.module}/.artifacts/manual-transactions-v1.tar.gz")
  activate    = true

  depends_on = [
    appwrite_tablesdb_column.manual_transactions,
    appwrite_tablesdb_index.manual_transactions_owner_modified,
    appwrite_function_variable.manual_transactions_database,
    appwrite_function_variable.manual_transactions_table,
  ]

  lifecycle {
    create_before_destroy = true
  }
}
