# The official Appwrite provider does not yet expose native platforms, auth
# method switches, or bucket stripMetadata. This bridge keeps their desired
# settings in Terraform and reads live values on every plan. It never deletes
# remote Appwrite resources. Every write is followed by a semantic readback.
locals {
  # Read from both live projects on 2026-11-09. Environment files override
  # the few settings that differ; future environments can do the same.
  service_defaults = {
    account    = true
    avatars    = true
    databases  = true
    tablesdb   = true
    locale     = true
    health     = true
    project    = true
    storage    = true
    teams      = false
    users      = true
    vcs        = true
    sites      = true
    functions  = true
    proxy      = true
    graphql    = true
    migrations = true
    messaging  = true
    advisor    = true
    oauth2     = true
  }
  protocol_defaults = {
    rest      = true
    graphql   = true
    websocket = true
  }
  policy_defaults = {
    password-dictionary    = { enabled = false, denyList = [] }
    password-history       = { total = 0 }
    password-strength      = { min = 8, uppercase = false, lowercase = false, number = false, symbols = false }
    password-personal-data = { enabled = false, denyList = [] }
    password-pwned         = { enabled = true, sessions = false, users = false }
    password-rotation      = { enabled = false, maxAge = 31536000 }
    session-alert          = { enabled = false }
    session-duration       = { duration = 31536000 }
    session-invalidation   = { enabled = true }
    session-limit          = { total = 10 }
    user-limit             = { total = 0 }
    membership-privacy     = { userId = false, userEmail = false, userPhone = false, userName = false, userMFA = false, userAccessedAt = false }
    mfa-factors            = { totp = true, email = true, phone = true, custom = false }
    deny-aliased-email     = { enabled = false }
    deny-disposable-email  = { enabled = false }
    deny-free-email        = { enabled = false }
    deny-corporate-email   = { enabled = false }
    deny-realtime-guests   = { enabled = false }
    passkey                = { rpId = "", origins = [] }
    account-devices        = { enabled = true }
  }

  appwrite_settings = merge(
    {
      bucket = {
        kind = "bucket"
        id   = var.bucket.id
        desired = {
          id                    = var.bucket.id
          name                  = var.bucket.name
          permissions           = var.bucket.permissions
          fileSecurity          = var.bucket.file_security
          enabled               = true
          maximumFileSize       = var.bucket.maximum_file_size
          allowedFileExtensions = var.bucket.allowed_file_extensions
          compression           = var.bucket.compression
          encryption            = var.bucket.encryption
          antivirus             = var.bucket.antivirus
          transformations       = var.bucket.transformations
          stripMetadata         = var.bucket.strip_metadata
        }
      }
    },
    {
      for name, platform in var.platforms : "platform_${name}" => {
        kind = "platform"
        id   = platform.id
        desired = merge({
          id   = platform.id
          type = platform.type
          name = platform.name
          }, platform.type == "android" ? {
          applicationId = platform.application_id
          } : {
          bundleIdentifier = platform.bundle_identifier
        })
      }
    },
    {
      for name, enabled in var.auth_methods : "auth_${name}" => {
        kind    = "auth_method"
        id      = name
        desired = { id = name, enabled = enabled }
      }
    },
    {
      for name, oauth in var.native_oauth : "oauth_${name}" => {
        kind = "oauth_native"
        id   = name
        desired = {
          id              = name
          enabled         = oauth.enabled
          nativeEnabled   = oauth.native_enabled
          nativeClientIds = oauth.native_client_ids
        }
      }
    },
    {
      for name, enabled in merge(local.service_defaults, var.service_overrides) : "service_${name}" => {
        kind    = "service"
        id      = name
        desired = { id = name, enabled = enabled }
      }
    },
    {
      for name, enabled in merge(local.protocol_defaults, var.protocol_overrides) : "protocol_${name}" => {
        kind    = "protocol"
        id      = name
        desired = { id = name, enabled = enabled }
      }
    },
    {
      for name, policy in merge(local.policy_defaults, var.policy_overrides) : "policy_${name}" => {
        kind    = "policy"
        id      = name
        desired = merge({ id = name }, policy)
      }
    }
  )
}

data "external" "setting" {
  for_each = merge(local.appwrite_settings, local.marketing_settings)
  program  = ["python3", "${path.module}/scripts/manage_setting.py", "read"]
  query = {
    endpoint   = var.endpoint
    project_id = var.project.id
    kind       = each.value.kind
    id         = each.value.id
  }
}

resource "terraform_data" "setting" {
  for_each = merge(local.appwrite_settings, local.marketing_settings)
  input    = each.value.desired
  triggers_replace = {
    desired  = sha256(jsonencode(each.value.desired))
    observed = sha256(data.external.setting[each.key].result.current)
  }

  provisioner "local-exec" {
    working_dir = path.module
    command     = "python3 scripts/manage_setting.py apply"
    environment = {
      SPROUT_APPWRITE_ENDPOINT   = var.endpoint
      SPROUT_APPWRITE_PROJECT_ID = var.project.id
      SPROUT_APPWRITE_KIND       = each.value.kind
      SPROUT_APPWRITE_ID         = each.value.id
      SPROUT_APPWRITE_DESIRED    = jsonencode(each.value.desired)
    }
  }
}
