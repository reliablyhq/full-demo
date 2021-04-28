# GCP project variables
variable "project_name" {
  description = "Provide a name that will be used as the GCP project identifier"
}

variable "gcp_org" {
  description = "The GCP organization name under which this project will be attached to"
}

variable "billing_account" {
  description = "The displayed name of GCP billing account to attach this project to"
}

#variable "org_id" {}
variable "region" {
  default = "europe-west1"
}

variable "zone" {
  default = "europe-west1-a"
}

variable "gcr" {
  default     = "eu.gcr.io"
  description = "Container registry hostname"
}

variable "domain" {
  description = "Domain that will be used to respond to requests from the load balancer"
}
