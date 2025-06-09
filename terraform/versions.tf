terraform {
  required_version = ">= 1.11.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.10"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.1.0"
    }
  }
}