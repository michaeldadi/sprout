# Deliberately separate from financial snapshot restoration. Retain this ledger
# and the disabled Auth ID reservation when restoring a financial database.
resource "appwrite_tablesdb" "privacy" {
  count      = var.enable_financial_backend ? 1 : 0
  project_id = var.project.id
  id         = "sprout-privacy"
  name       = "Privacy restoration ledger"
  enabled    = true
  lifecycle { prevent_destroy = true }
}
resource "appwrite_tablesdb_table" "deletion_ledger" {
  count        = var.enable_financial_backend ? 1 : 0
  project_id   = var.project.id
  database_id  = appwrite_tablesdb.privacy[0].id
  id           = "deletion_ledger"
  name         = "Hashed deletion ledger"
  enabled      = true
  row_security = true
  permissions  = []
  lifecycle { prevent_destroy = true }
}
resource "appwrite_tablesdb_column" "deletion_ledger" {
  for_each    = var.enable_financial_backend ? { owner_hash = "varchar", owner_id = "varchar", receipt_hash = "varchar", payload = "mediumtext", state = "varchar", updated_at = "datetime", lease_until = "datetime", revision = "bigint" } : {}
  project_id  = var.project.id
  database_id = appwrite_tablesdb.privacy[0].id
  table_id    = appwrite_tablesdb_table.deletion_ledger[0].id
  key         = each.key
  type        = each.value
  size        = each.value == "varchar" ? (each.key == "owner_id" ? 128 : 64) : null
  required    = each.key != "lease_until"
  encrypt     = each.value == "mediumtext" ? true : null
  min         = each.value == "bigint" ? 0 : null
  max         = each.value == "bigint" ? 9007199254740991 : null
  array       = false
  lifecycle { prevent_destroy = true }
}
resource "appwrite_tablesdb_index" "deletion_receipt" {
  count       = var.enable_financial_backend ? 1 : 0
  project_id  = var.project.id
  database_id = appwrite_tablesdb.privacy[0].id
  table_id    = appwrite_tablesdb_table.deletion_ledger[0].id
  key         = "receipt_hash"
  type        = "unique"
  columns     = ["receipt_hash"]
  depends_on  = [appwrite_tablesdb_column.deletion_ledger]
}
resource "appwrite_function_variable" "privacy_database" {
  for_each    = local.financial_functions
  project_id  = var.project.id
  function_id = appwrite_function.financial[each.key].id
  key         = "SPROUT_PRIVACY_DATABASE_ID"
  value       = appwrite_tablesdb.privacy[0].id
  secret      = false
}

resource "appwrite_tablesdb_index" "privacy_recovery" {
  count       = var.enable_financial_backend ? 1 : 0
  project_id  = var.project.id
  database_id = appwrite_tablesdb.privacy[0].id
  table_id    = appwrite_tablesdb_table.deletion_ledger[0].id
  key         = "state_updated"
  type        = "key"
  columns     = ["state", "updated_at"]
  orders      = ["asc", "asc"]
  depends_on  = [appwrite_tablesdb_column.deletion_ledger]
}
