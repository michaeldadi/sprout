# Snapshot of existing Appwrite Cloud configuration, read 2026-11-09.
# No credentials belong in this file.
environment     = "staging"
endpoint        = "https://nyc.cloud.appwrite.io/v1"
organization_id = "6af0e4a5003dead0e791"

project = {
  id     = "6af0f72200383d2f1084"
  name   = "Sprout (Staging)"
  region = "nyc"
}

database = {
  id   = "6af0f7c600244c241e44"
  name = "Staging TablesDB"
}

bucket = {
  id                      = "6af0f7db003a56687e73"
  name                    = "user-documents-staging"
  permissions             = []
  file_security           = false
  maximum_file_size       = 5000000000
  allowed_file_extensions = []
  compression             = "none"
  encryption              = true
  antivirus               = true
  transformations         = true
  strip_metadata          = false
}

platforms = {
  android = {
    id             = "6af0f85b00343e8ef11f"
    type           = "android"
    name           = "Sprout Android"
    application_id = "com.michaeldadi.sprout"
  }
  ios = {
    id                = "6af0f86a000a93869ade"
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
  session-duration = { duration = 31536000 }
  session-limit    = { total = 10 }
}

site = {
  id                     = "6af0f8bf003d74b49da3"
  name                   = "Sprout Web (Landing)"
  installation_id        = "6af0f74bcf81fafecac0"
  provider_repository_id = "1041147244"
}

site_variables = {
  VITE_APPWRITE_PROJECT_NAME = {
    id     = "6af0f8c2001f8a9c5eb8"
    value  = "Sprout (Staging)"
    secret = false
  }
  VITE_APPWRITE_ENDPOINT = {
    id     = "6af0f8c2001f8919ccfc"
    value  = "https://nyc.cloud.appwrite.io/v1"
    secret = false
  }
  VITE_APPWRITE_PROJECT_ID = {
    id     = "6af0f8c2001f8e1a346f"
    value  = "6af0f72200383d2f1084"
    secret = false
  }
}
