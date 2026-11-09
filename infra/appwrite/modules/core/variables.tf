variable "organization_id" {
  type = string
}

variable "project_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "database_id" {
  type = string
}

variable "database_name" {
  type = string
}

variable "site" {
  type = object({
    id                      = string
    name                    = string
    framework               = optional(string, "tanstack-start")
    adapter                 = optional(string, "ssr")
    build_runtime           = optional(string, "node-22")
    install_command         = optional(string, "npm install")
    build_command           = optional(string, "npm run build")
    start_command           = optional(string, "")
    output_directory        = optional(string, "./dist")
    fallback_file           = optional(string, "")
    installation_id         = string
    provider_repository_id  = string
    provider_branch         = optional(string, "main")
    provider_root_directory = optional(string, "./apps/web")
    provider_silent_mode    = optional(bool, false)
    build_specification     = optional(string, "s-2vcpu-2gb")
    runtime_specification   = optional(string, "s-0.5vcpu-512mb")
    deployment_retention    = optional(number, 0)
    timeout                 = optional(number, 30)
    logging                 = optional(bool, true)
    enabled                 = optional(bool, true)
  })
}

variable "site_variables" {
  type = map(object({
    id     = string
    value  = string
    secret = bool
  }))
}
