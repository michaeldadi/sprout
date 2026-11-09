terraform {
  required_version = ">= 1.11.0"

  required_providers {
    appwrite = {
      source  = "appwrite/appwrite"
      version = "= 2.3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "= 2.4.1"
    }
  }

  backend "remote" {}
}
