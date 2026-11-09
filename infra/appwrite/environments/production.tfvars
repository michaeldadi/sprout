# Snapshot of existing Appwrite Cloud configuration, read 2026-11-09.
# No credentials belong in this file.
environment     = "production"
endpoint        = "https://nyc.cloud.appwrite.io/v1"
organization_id = "6af0e4a5003dead0e791"

project = {
  id     = "6af0e4b00015b4aa04e3"
  name   = "Sprout"
  region = "nyc"
}

database = {
  id   = "6af0edbc001c7124b087"
  name = "Production TablesDB"
}

bucket = {
  id                      = "6af0edff00071924073c"
  name                    = "user-documents-prod"
  permissions             = ["create(\"users\")"]
  file_security           = false
  maximum_file_size       = 45000000
  allowed_file_extensions = ["jpg", "jpeg", "png", "heic", "tiff", "pdf", "webp"]
  compression             = "none"
  encryption              = true
  antivirus               = true
  transformations         = true
  strip_metadata          = true
}

platforms = {
  android = {
    id             = "6af0f460000468f7f23c"
    type           = "android"
    name           = "Sprout Android"
    application_id = "com.michaeldadi.sprout"
  }
  ios = {
    id                = "6af0f49b001b4d2a7082"
    type              = "apple"
    name              = "Sprout iOS"
    bundle_identifier = "com.michaeldadi.Sprout"
  }
}

auth_methods = {
  email-password = true
  magic-url      = true
  email-otp      = true
  anonymous      = false
  invites        = false
  jwt            = true
  phone          = false
  passkey        = false
}

native_oauth = {
  apple = {
    enabled           = false
    native_enabled    = true
    native_client_ids = ["com.michaeldadi.Sprout"]
  }
  google = {
    enabled           = false
    native_enabled    = true
    native_client_ids = ["580971148783-b04rqp82bnk3qv478l0bo0jtdunu4kkc.apps.googleusercontent.com"]
  }
}

policy_overrides = {
  session-duration = { duration = 15552000 }
  session-limit    = { total = 100 }
}

site = {
  id                     = "6af0f34a002cee7f0cfb"
  name                   = "Sprout Web (Landing)"
  installation_id        = "6af0eec28c8f2b3a5829"
  provider_repository_id = "1041147244"
}

site_variables = {
  VITE_APPWRITE_PROJECT_NAME = {
    id     = "6af0f34d000b846ed1a7"
    value  = "Sprout"
    secret = false
  }
  VITE_APPWRITE_ENDPOINT = {
    id     = "6af0f34d000b75924ade"
    value  = "https://nyc.cloud.appwrite.io/v1"
    secret = false
  }
  VITE_APPWRITE_PROJECT_ID = {
    id     = "6af0f34d000b824a2f0a"
    value  = "6af0e4b00015b4aa04e3"
    secret = false
  }
}

# Existing functions are adopted as configuration. Their Git deployments are
# build artifacts and are not imported as Terraform deployment resources.
functions = {
  monthly_pdf = {
    id                      = "6af0ef3e0024198abe1c"
    name                    = "Generate Monthly Expense Summary PDF"
    runtime                 = "node-26"
    entrypoint              = "src/main.js"
    commands                = "npm install"
    execute                 = ["any"]
    scopes                  = []
    events                  = []
    installation_id         = "6af0eec28c8f2b3a5829"
    provider_repository_id  = "1041147244"
    provider_branch         = "main"
    provider_root_directory = "./"
  }
  speech_recognition = {
    id                      = "6af0ef920020306df26f"
    name                    = "Speech recognition"
    runtime                 = "node-26"
    entrypoint              = "src/main.js"
    commands                = "npm install && npm run setup"
    execute                 = ["any"]
    scopes                  = ["databases.read", "databases.write", "collections.read", "tables.read", "collections.write", "tables.write", "attributes.write", "columns.write", "documents.read", "rows.read", "documents.write", "rows.write", "buckets.read", "buckets.write", "files.read"]
    events                  = ["buckets.*.files.*.create"]
    installation_id         = "6af0eec28c8f2b3a5829"
    provider_repository_id  = "1041147244"
    provider_branch         = "main"
    provider_root_directory = "./"
  }
  url_shortener = {
    id                      = "6af0f05f0039657ea7ed"
    name                    = "URL shortener"
    runtime                 = "node-26"
    entrypoint              = "src/main.js"
    commands                = "npm install"
    execute                 = ["any"]
    scopes                  = ["databases.read", "databases.write", "collections.write", "tables.write", "attributes.write", "columns.write", "documents.read", "rows.read", "documents.write", "rows.write"]
    events                  = []
    installation_id         = "6af0eec28c8f2b3a5829"
    provider_repository_id  = "1041147244"
    provider_branch         = "main"
    provider_root_directory = "./"
  }
  apple_sign_in = {
    id                      = "6af0f0b8001fa5f01dd7"
    name                    = "Sign in with Apple"
    runtime                 = "dart-3.13"
    entrypoint              = "lib/main.dart"
    commands                = "dart pub get"
    execute                 = ["any"]
    scopes                  = ["users.read", "users.write"]
    events                  = []
    installation_id         = "6af0eec28c8f2b3a5829"
    provider_repository_id  = "1041147244"
    provider_branch         = "main"
    provider_root_directory = "./"
  }
  fcm_push = {
    id                      = "6af0f103003bffc0a133"
    name                    = "Push notification with FCM"
    runtime                 = "node-26"
    entrypoint              = "src/main.js"
    commands                = "npm install"
    execute                 = ["any"]
    scopes                  = []
    events                  = []
    installation_id         = "6af0eec28c8f2b3a5829"
    provider_repository_id  = "1041147244"
    provider_branch         = "main"
    provider_root_directory = "./"
  }
}

function_variables = {
  speech_database = {
    id           = "6af0ef930035b0308858"
    function_key = "speech_recognition"
    key          = "APPWRITE_DATABASE_ID"
    value        = "ai"
    secret       = false
  }
  speech_collection = {
    id           = "6af0ef940008d10ee152"
    function_key = "speech_recognition"
    key          = "APPWRITE_COLLECTION_ID"
    value        = "speech_recognition"
    secret       = false
  }
  speech_bucket = {
    id           = "6af0ef9400132bb337ea"
    function_key = "speech_recognition"
    key          = "APPWRITE_BUCKET_ID"
    value        = "speech_recognition"
    secret       = false
  }
  speech_huggingface_token = {
    id           = "6af0ef94001d7a0e3e17"
    function_key = "speech_recognition"
    key          = "HUGGINGFACE_ACCESS_TOKEN"
    secret       = true
  }
  shortener_database = {
    id           = "6af0f06100127c00edf8"
    function_key = "url_shortener"
    key          = "APPWRITE_DATABASE_ID"
    value        = "urlShortener"
    secret       = false
  }
  shortener_collection = {
    id           = "6af0f0610023f74b9194"
    function_key = "url_shortener"
    key          = "APPWRITE_COLLECTION_ID"
    value        = "urls"
    secret       = false
  }
  shortener_base_url = {
    id           = "6af0f06100333e8b0c4d"
    function_key = "url_shortener"
    key          = "SHORT_BASE_URL"
    value        = "https://getsprout.io"
    secret       = false
  }
  apple_bundle_id = {
    id           = "6af0f0bb0004b9e4cac3"
    function_key = "apple_sign_in"
    key          = "BUNDLE_ID"
    value        = ""
    secret       = false
  }
  apple_team_id = {
    id           = "6af0f0bb001512ba7691"
    function_key = "apple_sign_in"
    key          = "TEAM_ID"
    value        = ""
    secret       = false
  }
  apple_key_id = {
    id           = "6af0f0bb00221b0c1bfa"
    function_key = "apple_sign_in"
    key          = "KEY_ID"
    value        = ""
    secret       = false
  }
  apple_key_contents = {
    id           = "6af0f0bb002d13bbc6a5"
    function_key = "apple_sign_in"
    key          = "KEY_CONTENTS_ENCODED"
    value        = ""
    secret       = false
  }
  fcm_project_id = {
    id           = "6af0f10600290a78ef75"
    function_key = "fcm_push"
    key          = "FCM_PROJECT_ID"
    value        = ""
    secret       = false
  }
  fcm_client_email = {
    id           = "6af0f106003c7d3072e6"
    function_key = "fcm_push"
    key          = "FCM_CLIENT_EMAIL"
    value        = ""
    secret       = false
  }
  fcm_private_key = {
    id           = "6af0f1070008ce190019"
    function_key = "fcm_push"
    key          = "FCM_PRIVATE_KEY"
    value        = ""
    secret       = false
  }
  fcm_database_url = {
    id           = "6af0f107001256e301fd"
    function_key = "fcm_push"
    key          = "FCM_DATABASE_URL"
    value        = ""
    secret       = false
  }
}

project_keys = {
  terraform = {
    id   = "6af0f671001b8ec6454d"
    name = "Terraform"
    scopes = [
      "executions.write",
      "executions.read",
      "functions.write",
      "functions.read",
      "buckets.read",
      "buckets.write",
      "databases.read",
      "databases.write",
      "tables.write",
      "tables.read",
      "indexes.write",
      "indexes.read",
      "embeddings.write",
      "columns.read",
      "columns.write",
      "providers.read",
      "providers.write",
      "targets.read",
      "targets.write",
      "topics.read",
      "topics.write",
      "log.read",
      "log.write",
      "sites.read",
      "sites.write",
      "presences.read",
      "presences.write",
      "domains.read",
      "domains.write",
      "project.write",
      "project.read",
      "project.policies.read",
      "project.policies.write",
      "platforms.read",
      "platforms.write",
      "keys.write",
      "keys.read",
      "mocks.read",
      "mocks.write",
      "events.read",
      "stages.read",
      "stages.write",
      "templates.read",
      "templates.write",
      "wafRules.read",
      "wafRules.write",
      "proxy.invalidations.write",
      "rules.write",
      "rules.read",
      "analytics.write",
      "analytics.read",
      "apps.write",
      "apps.read",
      "archives.read",
      "archives.write",
      "backups.policies.read",
      "backups.policies.write",
      "reviews.read",
      "reviews.write",
      "restorations.read",
      "restorations.write",
      "migrations.read",
      "migrations.write",
      "avatars.write",
      "avatars.read",
      "monitors.read",
      "monitors.write",
      "schedules.read",
      "schedules.write",
      "usage.read",
      "webhooks.read",
      "webhooks.write",
      "vcs.write",
      "vcs.read",
      "project.oauth2.write",
      "project.oauth2.read",
      "vectorsdb.write",
      "vectorsdb.read",
      "vectorsdb.indexes.write",
      "vectorsdb.indexes.read",
      "vectorsdb.documents.write",
      "vectorsdb.documents.read",
      "vectorsdb.collections.write",
      "vectorsdb.collections.read",
      "teams.write",
    ]
  }
}
