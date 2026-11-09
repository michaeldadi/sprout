# Website form data stays private. Only the site server receives rows.write.
locals {
  marketing_tables = {
    marketing_waitlist_v1  = "Marketing waitlist"
    marketing_inquiries_v1 = "Marketing inquiries"
  }
  marketing_columns = {
    waitlist_email     = { table = "marketing_waitlist_v1", key = "email", size = 254 }
    waitlist_platform  = { table = "marketing_waitlist_v1", key = "platform", size = 16 }
    waitlist_placement = { table = "marketing_waitlist_v1", key = "placement", size = 32 }
    waitlist_consent   = { table = "marketing_waitlist_v1", key = "consent_version", size = 64 }
    waitlist_time      = { table = "marketing_waitlist_v1", key = "consented_at", size = 32 }
    inquiry_email      = { table = "marketing_inquiries_v1", key = "email", size = 254 }
    inquiry_name       = { table = "marketing_inquiries_v1", key = "name", size = 100 }
    inquiry_category   = { table = "marketing_inquiries_v1", key = "category", size = 16 }
    inquiry_message    = { table = "marketing_inquiries_v1", key = "message", size = 5000 }
    inquiry_status     = { table = "marketing_inquiries_v1", key = "status", size = 16 }
  }
  marketing_site_variables = {
    SPROUT_MARKETING_DATABASE_ID = var.database.id
    SPROUT_WAITLIST_TABLE_ID     = "marketing_waitlist_v1"
    SPROUT_INQUIRIES_TABLE_ID    = "marketing_inquiries_v1"
    SPROUT_SITE_ORIGIN           = var.marketing_site_origin
    VITE_SITE_ORIGIN             = var.marketing_site_origin
    VITE_SITE_INDEXABLE          = tostring(var.marketing_site_indexable)
  }
  marketing_settings = merge(
    {
      marketing_site = {
        kind = "site_marketing"
        id   = module.core.site_id
        desired = {
          id               = module.core.site_id
          scopes           = ["rows.write"]
          providerBranches = ["main", "codex/sprout-clear-sky"]
          providerPaths    = ["apps/web/**", "package.json", "yarn.lock", ".yarnrc.yml", "infra/appwrite/**"]
        }
      }
    },
    {
      for index, endpoint in ["waitlist", "contact"] : "marketing_rate_${endpoint}" => {
        kind = "waf_rate"
        id   = "marketing_${endpoint}_rate"
        desired = {
          id           = "marketing_${endpoint}_rate"
          resourceType = "sites"
          resourceId   = module.core.site_id
          name         = "Marketing ${endpoint} submissions"
          limit        = 5
          interval     = 60
          key          = "ip"
          strategy     = "fixedWindow"
          priority     = 100 + index
          enabled      = true
          conditions = [
            jsonencode({ attribute = "method", method = "equal", values = ["POST"] }),
            jsonencode({ attribute = "path", method = "equal", values = ["/api/${endpoint}"] })
          ]
        }
      }
    }
  )
}

variable "marketing_site_origin" {
  type        = string
  default     = ""
  description = "Exact generated primary site origin; required before accepting hosted submissions."
  validation {
    condition     = var.marketing_site_origin == "" || can(regex("^https://[^/]+$", var.marketing_site_origin))
    error_message = "Use an HTTPS origin without a path or trailing slash."
  }
}
variable "marketing_site_indexable" {
  type    = bool
  default = false
}

resource "appwrite_tablesdb_table" "marketing" {
  for_each     = local.marketing_tables
  project_id   = var.project.id
  database_id  = var.database.id
  id           = each.key
  name         = each.value
  permissions  = []
  row_security = true
  enabled      = true
  lifecycle { prevent_destroy = true }
}
resource "appwrite_tablesdb_column" "marketing" {
  for_each    = local.marketing_columns
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.marketing[each.value.table].id
  key         = each.value.key
  type        = "string"
  size        = each.value.size
  required    = true
}
resource "appwrite_tablesdb_index" "marketing_email" {
  project_id  = var.project.id
  database_id = var.database.id
  table_id    = appwrite_tablesdb_table.marketing["marketing_waitlist_v1"].id
  key         = "unique_email"
  type        = "unique"
  columns     = ["email"]
  depends_on  = [appwrite_tablesdb_column.marketing]
}
resource "appwrite_site_variable" "marketing" {
  for_each   = local.marketing_site_variables
  project_id = var.project.id
  site_id    = var.site.id
  key        = each.key
  value      = each.value
  secret     = false
}
