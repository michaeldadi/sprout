terraform {
  required_version = ">= 1.11.0"

  required_providers {
    appwrite = {
      source  = "appwrite/appwrite"
      version = "= 2.3.0"
    }
  }
}
