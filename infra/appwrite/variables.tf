variable "environment" {
  type        = string
  description = "Logical name for the selected Terraform workspace and Appwrite project."
}

variable "endpoint" {
  type = string
}

variable "organization_id" {
  type = string
}

variable "project" {
  type = object({
    id     = string
    name   = string
    region = string
  })
}

variable "database" {
  type = object({
    id   = string
    name = string
  })
}

variable "bucket" {
  type = object({
    id                      = string
    name                    = string
    permissions             = list(string)
    file_security           = bool
    maximum_file_size       = number
    allowed_file_extensions = list(string)
    compression             = string
    encryption              = bool
    antivirus               = bool
    transformations         = bool
    strip_metadata          = bool
  })
}

variable "platforms" {
  type = map(object({
    id                = string
    type              = string
    name              = string
    application_id    = optional(string)
    bundle_identifier = optional(string)
  }))
  validation {
    condition     = alltrue([for p in values(var.platforms) : contains(["android", "apple"], p.type)])
    error_message = "Only the Android and Apple Appwrite platform types are configured here."
  }
}

variable "auth_methods" {
  type = map(bool)
}

variable "native_oauth" {
  type = map(object({
    enabled           = bool
    native_enabled    = bool
    native_client_ids = list(string)
  }))
  default = {}
  validation {
    condition     = alltrue([for name in keys(var.native_oauth) : contains(["apple", "google"], name)])
    error_message = "Only the Apple and Google native OAuth configurations are modeled here."
  }
}

variable "service_overrides" {
  type    = map(bool)
  default = {}
}

variable "protocol_overrides" {
  type    = map(bool)
  default = {}
}

variable "policy_overrides" {
  type    = any
  default = {}
}

variable "site" {
  type = any
}

variable "site_variables" {
  type = map(object({
    id     = string
    value  = string
    secret = bool
  }))
}

variable "functions" {
  type = map(object({
    id                      = string
    name                    = string
    runtime                 = string
    entrypoint              = string
    commands                = string
    execute                 = list(string)
    scopes                  = list(string)
    events                  = list(string)
    installation_id         = string
    provider_repository_id  = string
    provider_branch         = string
    provider_root_directory = string
  }))
  default = {}
}

variable "function_variables" {
  type = map(object({
    id           = string
    function_key = string
    key          = string
    value        = optional(string)
    secret       = bool
  }))
  default = {}
}

variable "function_secret_values" {
  type        = map(string)
  sensitive   = true
  default     = {}
  description = "Secret function variable values supplied outside source control."
}

variable "project_keys" {
  type = map(object({
    id     = string
    name   = string
    scopes = set(string)
  }))
  default = {}
}
