# Opt in after a reviewed staging plan. No financial client write grants.
variable "enable_financial_backend" {
  type    = bool
  default = false
}

variable "financial_flags" {
  type = object({
    FINANCIAL_WRITES    = optional(bool, false)
    LINKING             = optional(bool, false)
    AI                  = optional(bool, false)
    FORECASTS           = optional(bool, false)
    NOTIFICATIONS       = optional(bool, false)
    CANCELLATION        = optional(bool, false)
    SCAN_ASSISTANCE     = optional(bool, false)
    FIRST_PARTY_ERASURE = optional(bool, false)
  })
  default = {}
}
variable "financial_secret_values" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = "Write-only secrets keyed by function/environment-variable, for example api/PLAID_SECRET. Never put values in committed tfvars."
  validation {
    condition     = alltrue([for name in keys(var.financial_secret_values) : can(regex("^(api|webhooks|worker|ai|dispatcher|privacy)/[A-Z][A-Z0-9_]{1,63}$", name))])
    error_message = "Secret keys must select a known function and uppercase environment variable."
  }
}
variable "financial_secret_versions" {
  type    = map(number)
  default = {}
}

locals {
  canonical_tables     = toset(["profiles", "transactions", "budgets", "goals", "recurring_decisions", "reminders", "actions", "insight_feedback", "connections", "accounts", "jobs", "entitlements", "conversations", "privacy_jobs", "usage", "notifications", "action_events"])
  private_tables       = toset(["provider_credentials", "webhook_receipts", "import_inputs", "receipts"])
  all_financial_tables = var.enable_financial_backend ? setunion(local.canonical_tables, local.private_tables, toset(["sync_heads", "sync_events", "mutation_receipts"])) : toset([])
  common_columns = [
    { key = "entity_id", type = "varchar", size = 128 },
    { key = "version", type = "bigint", size = null },
    { key = "updated_at", type = "datetime", size = null },
    { key = "deleted", type = "boolean", size = null },
    { key = "payload", type = "mediumtext", size = null }
  ]
  financial_columns = { for c in concat(
    [for table in local.all_financial_tables : { table = table, key = "owner", type = "varchar", size = 128 }],
    flatten([for table in setunion(local.canonical_tables, local.private_tables) : [for column in local.common_columns : merge(column, { table = table })] if var.enable_financial_backend]),
    var.enable_financial_backend ? [
      { table = "sync_heads", key = "sequence", type = "bigint", size = null },
      { table = "sync_events", key = "sequence", type = "bigint", size = null },
      { table = "sync_events", key = "payload", type = "mediumtext", size = null },
      { table = "mutation_receipts", key = "request_hash", type = "varchar", size = 64 },
      { table = "mutation_receipts", key = "payload", type = "mediumtext", size = null },
      { table = "jobs", key = "state", type = "varchar", size = 32 },
      { table = "jobs", key = "due_at", type = "datetime", size = null },
      { table = "jobs", key = "lease_until", type = "datetime", size = null },
      { table = "connections", key = "provider_reference", type = "varchar", size = 160 }
    ] : []
  ) : "${c.table}.${c.key}" => c }
  financial_functions = var.enable_financial_backend ? {
    api              = { timeout = 15, execute = ["users"], schedule = "", scopes = ["rows.read", "rows.write", "executions.write"] }
    webhooks         = { timeout = 15, execute = ["any"], schedule = "", scopes = ["rows.read", "rows.write"] }
    worker           = { timeout = 300, execute = [], schedule = "", scopes = ["rows.read", "rows.write"] }
    ai               = { timeout = 120, execute = [], schedule = "", scopes = ["rows.read", "rows.write"] }
    dispatcher       = { timeout = 60, execute = [], schedule = "*/5 * * * *", scopes = ["rows.read", "executions.write"] }
    "privacy-status" = { timeout = 15, execute = ["any"], schedule = "", scopes = ["rows.read"] }
    privacy          = { timeout = 300, execute = [], schedule = "", scopes = ["rows.read", "rows.write", "files.read", "files.write", "users.read", "users.write"] }
  } : {}
  financial_flag_variables = { for pair in flatten([for function in keys(local.financial_functions) : [for name, value in var.financial_flags : { function = function, name = "SPROUT_${name}", value = tostring(value) }]]) : "${pair.function}.${pair.name}" => pair }
}

resource "appwrite_tablesdb_table" "financial" {
  for_each     = local.all_financial_tables
  project_id   = var.project.id
  database_id  = var.database.id
  id           = each.key
  name         = replace(title(replace(each.key, "_", " ")), " ", " ")
  enabled      = true
  row_security = true
  permissions  = []
  lifecycle { prevent_destroy = true }
}
resource "appwrite_tablesdb_column" "financial" {
  for_each    = local.financial_columns
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.financial[each.value.table].id
  key         = each.value.key
  type        = each.value.type
  size        = each.value.size
  required    = !contains(["lease_until", "state", "due_at", "provider_reference"], each.value.key)
  min         = each.value.type == "bigint" ? -9223372036854775808 : null
  max         = each.value.type == "bigint" ? 9223372036854775807 : null
  array       = false
  encrypt     = each.value.type == "mediumtext" ? true : null
  lifecycle { prevent_destroy = true }
}
resource "appwrite_tablesdb_index" "owner_records" {
  for_each    = var.enable_financial_backend ? setunion(local.canonical_tables, local.private_tables) : toset([])
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.financial[each.key].id
  key         = "owner_active"
  type        = "key"
  columns     = ["owner", "deleted"]
  orders      = ["asc", "asc"]
  depends_on  = [appwrite_tablesdb_column.financial]
}
resource "appwrite_tablesdb_index" "sync_sequence" {
  count       = var.enable_financial_backend ? 1 : 0
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.financial["sync_events"].id
  key         = "owner_sequence"
  type        = "unique"
  columns     = ["owner", "sequence"]
  orders      = ["asc", "asc"]
  depends_on  = [appwrite_tablesdb_column.financial]
}
resource "appwrite_tablesdb_index" "due_jobs" {
  count       = var.enable_financial_backend ? 1 : 0
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.financial["jobs"].id
  key         = "state_due"
  type        = "key"
  columns     = ["state", "due_at"]
  orders      = ["asc", "asc"]
  depends_on  = [appwrite_tablesdb_column.financial]
}
resource "appwrite_tablesdb_index" "connection_provider" {
  count       = var.enable_financial_backend ? 1 : 0
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.financial["connections"].id
  key         = "provider_reference"
  type        = "unique"
  columns     = ["provider_reference"]
  depends_on  = [appwrite_tablesdb_column.financial]
}
resource "appwrite_function" "financial" {
  for_each   = local.financial_functions
  project_id = var.project.id
  id         = "sprout-${each.key}"
  name       = "Sprout ${title(each.key)}"
  runtime    = "node-22"
  entrypoint = "main.js"
  commands   = ""
  execute    = each.value.execute
  scopes     = each.value.scopes
  # Transaction commits can emit create/update for staged upserts. Subscribe to
  # the row family; leases make duplicate wakes safe and cron recovers misses.
  events                = each.key == "dispatcher" ? ["tablesdb.${var.database.id}.tables.jobs.rows.*"] : []
  schedule              = each.value.schedule
  timeout               = each.value.timeout
  logging               = false
  enabled               = true
  build_specification   = "s-2vcpu-2gb"
  runtime_specification = "s-0.5vcpu-512mb"
  deployment_retention  = 3
  lifecycle { prevent_destroy = true }
}
resource "appwrite_function_variable" "financial_database" {
  for_each    = local.financial_functions
  project_id  = var.project.id
  function_id = appwrite_function.financial[each.key].id
  key         = "SPROUT_DATABASE_ID"
  value       = var.database.id
  secret      = false
}
resource "appwrite_function_variable" "financial_environment" {
  for_each    = local.financial_functions
  project_id  = var.project.id
  function_id = appwrite_function.financial[each.key].id
  key         = "SPROUT_ENVIRONMENT"
  value       = var.environment
  secret      = false
}
resource "appwrite_function_variable" "plaid_environment" {
  for_each    = var.enable_financial_backend ? toset(["api", "webhooks", "worker"]) : toset([])
  project_id  = var.project.id
  function_id = appwrite_function.financial[each.key].id
  key         = "PLAID_ENVIRONMENT"
  value       = var.environment == "production" ? "production" : "sandbox"
  secret      = false
}
resource "appwrite_function_variable" "financial_flags" {
  for_each    = local.financial_flag_variables
  project_id  = var.project.id
  function_id = appwrite_function.financial[each.value.function].id
  key         = each.value.name
  value       = each.value.value
  secret      = false
}
resource "appwrite_function_variable" "financial_secrets" {
  for_each         = var.enable_financial_backend ? toset(keys(var.financial_secret_versions)) : toset([])
  project_id       = var.project.id
  function_id      = appwrite_function.financial[split("/", each.value)[0]].id
  key              = split("/", each.value)[1]
  value_wo         = lookup(var.financial_secret_values, each.value, "")
  value_wo_version = lookup(var.financial_secret_versions, each.value, 1)
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = contains(keys(var.financial_secret_values), each.value)
      error_message = "Load the declared financial secrets securely before planning. Missing values must never remove a live secret."
    }
  }
  secret = true
}

resource "appwrite_storage_bucket" "financial_private" {
  count                   = var.enable_financial_backend ? 1 : 0
  project_id              = var.project.id
  id                      = "sprout-private"
  name                    = "Private receipts and exports"
  enabled                 = true
  permissions             = []
  file_security           = true
  maximum_file_size       = 10000000
  allowed_file_extensions = ["jpg", "jpeg", "png", "pdf", "json"]
  compression             = "none"
  encryption              = true
  antivirus               = true
  transformations         = false
  lifecycle { prevent_destroy = true }
}
resource "appwrite_function_variable" "privacy_bucket" {
  count       = var.enable_financial_backend ? 1 : 0
  project_id  = var.project.id
  function_id = appwrite_function.financial["privacy"].id
  key         = "SPROUT_PRIVATE_BUCKET_ID"
  value       = appwrite_storage_bucket.financial_private[0].id
  secret      = false
}
variable "enable_financial_backups" {
  type    = bool
  default = false
}
variable "financial_backup_policy" {
  type    = object({ id = string, name = string, services = list(string), retention = number, schedule = string })
  default = { id = "sprout-financial-daily", name = "Daily financial backup", services = ["tablesdb"], retention = 7, schedule = "0 8 * * *" }
}
resource "appwrite_backup_policy" "financial" {
  count       = var.enable_financial_backend && var.enable_financial_backups ? 1 : 0
  project_id  = var.project.id
  id          = var.financial_backup_policy.id
  name        = var.financial_backup_policy.name
  enabled     = true
  services    = var.financial_backup_policy.services
  resource_id = var.database.id
  retention   = var.financial_backup_policy.retention
  schedule    = var.financial_backup_policy.schedule
  lifecycle { prevent_destroy = true }
}
