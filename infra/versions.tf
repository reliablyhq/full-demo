terraform {
  required_version = ">= 0.15"

  required_providers {
    google = {
      version = "~> 3.64"
    }

    google-beta = {
      version = "~> 3.64"
    }

    random = {
      version = "~> 3.1"
    }
  }
}
