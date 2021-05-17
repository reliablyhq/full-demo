###############################################################################
# Configure the terraform providers
###############################################################################
provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

###############################################################################
# Configure the terraform providers
###############################################################################
data "google_organization" "chaosiq_org" {
  domain = var.gcp_org
}

data "google_billing_account" "chaosiq_billing" {
  display_name = var.billing_account
  open         = true
}

locals {
  managed_domains = [var.domain]
}

###############################################################################
# Creating a GCP project
###############################################################################
resource "random_id" "id" {
  byte_length = 4
  prefix      = lower(replace("${var.project_name}-", " ", "-"))
}

resource "google_project" "project" {
  name            = var.project_name
  project_id      = random_id.id.hex
  billing_account = data.google_billing_account.chaosiq_billing.id
  org_id          = data.google_organization.chaosiq_org.org_id
}

resource "google_project_service" "service" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "container.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "run.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com"
  ])

  service = each.key

  project                    = google_project.project.project_id
  disable_on_destroy         = true
  disable_dependent_services = true
}

###############################################################################
# Creating a VPC to not use the default network
###############################################################################
resource "google_compute_network" "vpc" {
  project = google_project.project.project_id
  name    = "${google_project.project.project_id}-vpc"
  # auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  project       = google_project.project.project_id
  name          = "${google_project.project.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_vpc_access_connector" "connector" {
  project       = google_project.project.project_id
  name          = "api"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
}

resource "google_compute_global_address" "private_ip_address" {
  project       = google_project.project.project_id
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

###############################################################################
# Create TLS certificates managed by GCP directly so we don't have to
###############################################################################
resource "google_compute_managed_ssl_certificate" "default" {
  project = google_project.project.project_id
  name    = random_id.certificate.hex

  managed {
    domains = local.managed_domains
  }
}

resource "random_id" "certificate" {
  byte_length = 4
  prefix      = "reliably-demo-cert-"

  keepers = {
    domains = join(",", local.managed_domains)
  }
}

###############################################################################
# Create a global static address to which assign the domain to
###############################################################################
resource "google_compute_global_address" "default" {
  project      = google_project.project.project_id
  name         = "reliably-demo-lb-global-address"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}


################################################################################
# Create a GKE cluster
################################################################################
# resource "random_pet" "gke_cluster_name" {
#   length    = 2
#   separator = "-"
# }

# # Service Account to use instead of the default one
# resource "google_service_account" "apps_cluster_node_sa" {
#   project      = google_project.project.project_id
#   account_id   = "apps-gke"
#   display_name = "GKE nodes service account"
# }

# resource "google_project_iam_member" "apps_cluster_node_sa_metric_writer" {
#   project = google_project.project.project_id
#   role    = "roles/monitoring.metricWriter"
#   member  = "serviceAccount:${google_service_account.apps_cluster_node_sa.email}"
# }

# resource "google_project_iam_member" "apps_cluster_node_sa_mon_viewer" {
#   project = google_project.project.project_id
#   role    = "roles/monitoring.viewer"
#   member  = "serviceAccount:${google_service_account.apps_cluster_node_sa.email}"
# }

# resource "google_project_iam_member" "apps_cluster_node_sa_log_writer" {
#   project = google_project.project.project_id
#   role    = "roles/logging.logWriter"
#   member  = "serviceAccount:${google_service_account.apps_cluster_node_sa.email}"
# }

# resource "google_project_iam_member" "apps_cluster_node_sa_storage_viewer_on_container_images" {
#   project = google_project.project.project_id
#   role    = "roles/storage.objectViewer"
#   member  = "serviceAccount:${google_service_account.apps_cluster_node_sa.email}"
# }

# resource "google_container_cluster" "primary" {
#   name                     = "cluster-${random_pet.gke_cluster_name.id}"
#   project                  = google_project.project.project_id
#   location                 = var.region
#   remove_default_node_pool = true
#   initial_node_count       = 1

#   # Setting an empty username and password explicitly disables basic auth
#   master_auth {
#     username = ""
#     password = ""
#     client_certificate_config {
#       issue_client_certificate = false
#     }
#   }

#   logging_service    = "none"
#   monitoring_service = "none"
#   network            = google_compute_network.vpc.self_link
#   subnetwork         = google_compute_subnetwork.subnet.self_link

#   workload_identity_config {
#     identity_namespace = "${google_project.project.project_id}.svc.id.goog"
#   }

#   addons_config {
#     network_policy_config {
#       disabled = true
#     }

#     http_load_balancing {
#       disabled = true
#     }

#     horizontal_pod_autoscaling {
#       disabled = true
#     }

#     cloudrun_config {
#       disabled = true
#     }
#   }

#   maintenance_policy {
#     daily_maintenance_window {
#       start_time = "00:00"
#     }
#   }

#   pod_security_policy_config {
#     enabled = false
#   }

#   timeouts {
#     create = "30m"
#     update = "40m"
#   }
# }

# resource "google_container_node_pool" "apps_cluster_node" {
#   cluster    = google_container_cluster.primary.name
#   project    = google_project.project.project_id
#   location   = var.region
#   node_count = 1

#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }

#   autoscaling {
#     min_node_count = 1
#     max_node_count = 3
#   }

#   node_config {
#     image_type      = "COS"
#     machine_type    = "n1-standard-1"
#     service_account = google_service_account.apps_cluster_node_sa.email

#     oauth_scopes = [
#       "https://www.googleapis.com/auth/compute",
#       "https://www.googleapis.com/auth/devstorage.read_write",
#       "https://www.googleapis.com/auth/logging.write",
#       "https://www.googleapis.com/auth/monitoring",
#       "https://www.googleapis.com/auth/sqlservice.admin",
#       "https://www.googleapis.com/auth/cloud-platform",
#       "https://www.googleapis.com/auth/service.management"
#     ]
#   }
# }

# resource "google_compute_network_endpoint_group" "gke" {
#   project    = google_project.project.project_id
#   name       = "zonal-neg"
#   zone       = "${var.region}-b"
#   network    = google_compute_network.vpc.id
#   subnetwork = google_compute_subnetwork.subnet.id
# }


# resource "google_compute_health_check" "gke-health-check" {
#   project = google_project.project.project_id
#   name    = "gke-health-check"

#   http_health_check {
#     port = "443"
#   }
# }


################################################################################
# Create a Cloud SQL 2nd generation instance
################################################################################
resource "google_sql_database_instance" "main" {
  project          = google_project.project.project_id
  database_version = "POSTGRES_13"
  region           = var.region
  depends_on       = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = "db-g1-small"
    availability_type = "REGIONAL"

    location_preference {
      zone = "${var.region}-b"
    }

    maintenance_window {
      day          = 7
      hour         = 14
      update_track = "stable"
    }

    ip_configuration {
      require_ssl     = true
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled    = true
      start_time = "07:00"
    }
  }
}

resource "google_sql_database" "db" {
  name      = "demo-db"
  project   = google_project.project.project_id
  instance  = google_sql_database_instance.main.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

resource "google_sql_ssl_cert" "client_cert" {
  project     = google_project.project.project_id
  common_name = "demo"
  instance    = google_sql_database_instance.main.name
}

resource "random_id" "db_user_password" {
  byte_length = 8
}

resource "google_sql_user" "user" {
  project  = google_project.project.project_id
  instance = google_sql_database_instance.main.name
  name     = "demo"
  password = random_id.db_user_password.hex
}

resource "google_service_account" "db_user" {
  project      = google_project.project.project_id
  account_id   = "demodb"
  display_name = "Demo database user"
}

resource "google_service_account_key" "db_user_key" {
  service_account_id = google_service_account.db_user.name
}

resource "google_project_iam_member" "db_user_iam_binding" {
  project = google_project.project.project_id
  member  = "serviceAccount:${google_service_account.db_user.email}"
  role    = "roles/cloudsql.client"
}



################################################################################
# Create a basic Cloud Run service
################################################################################
resource "google_service_account" "hello" {
  project      = google_project.project.project_id
  account_id   = "hello-service"
  display_name = "Hello service Cloud Run"
}

resource "google_project_iam_member" "hello_sa_storage_viewer_on_container_images" {
  project = google_project.project.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.hello.email}"
}

resource "google_compute_region_network_endpoint_group" "hello" {
  project               = google_project.project.project_id
  name                  = "hello"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.hello.name
  }
}

resource "google_cloud_run_service" "hello" {
  project                    = google_project.project.project_id
  name                       = "hello"
  location                   = var.region
  autogenerate_revision_name = true

  metadata {
    namespace = google_project.project.project_id
    labels = {
      "cloud.googleapis.com/location" = var.region
    }
  }

  template {
    spec {
      service_account_name = google_service_account.hello.email
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "128Mi"
          }
        }
      }
    }
    metadata {
      annotations = {
        # see https://github.com/hashicorp/terraform-provider-google/issues/6294
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.id
        "run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.main.connection_name
        "run.googleapis.com/client-name"          = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "hello" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "hello" {
  location = google_cloud_run_service.hello.location
  project  = google_cloud_run_service.hello.project
  service  = google_cloud_run_service.hello.name

  policy_data = data.google_iam_policy.hello.policy_data
}

################################################################################
# Create Cloud Run service for the Noteboard application
################################################################################
resource "google_service_account" "noteboard-frontend" {
  project      = google_project.project.project_id
  account_id   = "noteboard-frontend"
  display_name = "Noteboard frontend service Cloud Run"
}

resource "google_project_iam_member" "noteboard-frontend_sa_storage_viewer_on_container_images" {
  project = var.chaosiq_devops_project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:service-${google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_compute_region_network_endpoint_group" "noteboard-frontend" {
  project               = google_project.project.project_id
  name                  = "noteboard-frontend"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.noteboard-frontend.name
  }
}

resource "google_cloud_run_service" "noteboard-frontend" {
  project                    = google_project.project.project_id
  name                       = "noteboard-frontend"
  location                   = var.region
  autogenerate_revision_name = true

  metadata {
    namespace = google_project.project.project_id
    labels = {
      "cloud.googleapis.com/location" = var.region
    }
  }

  template {
    spec {
      service_account_name = google_service_account.noteboard-frontend.email
      containers {
        image = "eu.gcr.io/chaosiq-devops/noteboard-frontend-demo"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "128Mi"
          }
        }
        env {
          name  = "SECRET_KEY"
          value = "secret"
        }
        env {
          name  = "SERVER_HOST"
          value = "https://${var.domain}"
        }
        env {
          name  = "SERVER_NAME"
          value = var.domain
        }
        env {
          name  = "API_URL"
          value = "https://${var.domain}/noteboard/api/v1"
        }
      }
    }
    metadata {
      annotations = {
        # see https://github.com/hashicorp/terraform-provider-google/issues/6294
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.id
        "run.googleapis.com/client-name"          = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noteboard-frontend" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noteboard-frontend" {
  location = google_cloud_run_service.noteboard-frontend.location
  project  = google_cloud_run_service.noteboard-frontend.project
  service  = google_cloud_run_service.noteboard-frontend.name

  policy_data = data.google_iam_policy.noteboard-frontend.policy_data
}

resource "google_service_account" "noteboard-api" {
  project      = google_project.project.project_id
  account_id   = "noteboard-api"
  display_name = "Noteboard api service Cloud Run"
}

resource "google_project_iam_member" "noteboard-api_sa_storage_viewer_on_container_images" {
  project = var.chaosiq_devops_project
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:service-${google_project.project.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

resource "google_compute_region_network_endpoint_group" "noteboard-api" {
  project               = google_project.project.project_id
  name                  = "noteboard-api"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.noteboard-api.name
  }
}

resource "google_secret_manager_secret" "notebook-api-dburi" {
  project  = google_project.project.project_id
  provider = google-beta

  secret_id = "notebook-api-dburi"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "notebook-api-dburi" {
  provider = google-beta

  secret      = google_secret_manager_secret.notebook-api-dburi.name
  secret_data = "postgres://${google_sql_user.user.name}:${random_id.db_user_password.hex}@${google_sql_database_instance.main.private_ip_address}:5432/${google_sql_database.db.name}"
}

resource "google_secret_manager_secret_iam_member" "notebook-api-dburi" {
  provider = google-beta

  secret_id  = google_secret_manager_secret.notebook-api-dburi.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.noteboard-api.email}"
  depends_on = [google_secret_manager_secret.notebook-api-dburi]
}

resource "google_secret_manager_secret" "notebook-api-dbclientcert" {
  project  = google_project.project.project_id
  provider = google-beta

  secret_id = "notebook-api-dbclientcert"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "notebook-api-dbclientcert" {
  provider = google-beta

  secret      = google_secret_manager_secret.notebook-api-dbclientcert.name
  secret_data = google_sql_ssl_cert.client_cert.cert
}

resource "google_secret_manager_secret_iam_member" "notebook-api-dbclientcert" {
  provider = google-beta

  secret_id  = google_secret_manager_secret.notebook-api-dbclientcert.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.noteboard-api.email}"
  depends_on = [google_secret_manager_secret.notebook-api-dbclientcert]
}

resource "google_secret_manager_secret" "notebook-api-dbclientkey" {
  project  = google_project.project.project_id
  provider = google-beta

  secret_id = "notebook-api-dbclientkey"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "notebook-api-dbclientkey" {
  provider = google-beta

  secret      = google_secret_manager_secret.notebook-api-dbclientkey.name
  secret_data = google_sql_ssl_cert.client_cert.private_key
}

resource "google_secret_manager_secret_iam_member" "notebook-api-dbclientkey" {
  provider = google-beta

  secret_id  = google_secret_manager_secret.notebook-api-dbclientkey.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.noteboard-api.email}"
  depends_on = [google_secret_manager_secret.notebook-api-dbclientkey]
}

resource "google_secret_manager_secret" "notebook-api-dbrootca" {
  project  = google_project.project.project_id
  provider = google-beta

  secret_id = "notebook-api-dbrootca"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "notebook-api-dbrootca" {
  provider = google-beta

  secret      = google_secret_manager_secret.notebook-api-dbrootca.name
  secret_data = google_sql_ssl_cert.client_cert.server_ca_cert
}

resource "google_secret_manager_secret_iam_member" "notebook-api-dbrootca" {
  provider = google-beta

  secret_id  = google_secret_manager_secret.notebook-api-dbrootca.id
  role       = "roles/secretmanager.secretAccessor"
  member     = "serviceAccount:${google_service_account.noteboard-api.email}"
  depends_on = [google_secret_manager_secret.notebook-api-dbrootca]
}

resource "google_cloud_run_service" "noteboard-api" {
  provider                   = google-beta
  project                    = google_project.project.project_id
  name                       = "noteboard-api"
  location                   = var.region
  autogenerate_revision_name = true
  depends_on                 = [google_secret_manager_secret_version.notebook-api-dburi]

  metadata {
    namespace = google_project.project.project_id
    labels = {
      "cloud.googleapis.com/location" = var.region
    }
    annotations = {
      "run.googleapis.com/launch-stage" = "ALPHA"
    }
  }

  template {
    spec {
      service_account_name = google_service_account.noteboard-api.email
      containers {
        image = "eu.gcr.io/chaosiq-devops/noteboard-api-demo"
        resources {
          limits = {
            cpu    = "1000m"
            memory = "128Mi"
          }
        }
        env {
          name  = "SECRET_KEY"
          value = "secret"
        }
        env {
          name  = "SERVER_HOST"
          value = "https://${var.domain}"
        }
        env {
          name  = "SERVER_NAME"
          value = var.domain
        }
        env {
          name  = "PROJECT_NAME"
          value = google_project.project.name
        }
        env {
          name  = "DATABASE_WITH_SSL"
          value = "1"
        }
        env {
          name  = "SQLALCHEMY_DATABASE_URI"
          value = "${google_secret_manager_secret.notebook-api-dburi.name}/versions/latest"
        }
        env {
          name  = "DATABASE_SSL_SERVER_CA_FILE"
          value = "${google_secret_manager_secret.notebook-api-dbrootca.name}/versions/latest"
        }
        env {
          name  = "DATABASE_SSL_CLIENT_CERT_FILE"
          value = "${google_secret_manager_secret.notebook-api-dbclientcert.name}/versions/latest"
        }
        env {
          name  = "DATABASE_SSL_CLIENT_KEY_FILE"
          value = "${google_secret_manager_secret.notebook-api-dbclientkey.name}/versions/latest"
        }
      }
    }
    metadata {
      annotations = {
        # see https://github.com/hashicorp/terraform-provider-google/issues/6294
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.id
        "run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.main.connection_name
        "run.googleapis.com/client-name"          = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noteboard-api" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noteboard-api" {
  location = google_cloud_run_service.noteboard-api.location
  project  = google_cloud_run_service.noteboard-api.project
  service  = google_cloud_run_service.noteboard-api.name

  policy_data = data.google_iam_policy.noteboard-api.policy_data
}


################################################################################
# Configure the Load Balancer
################################################################################
resource "google_compute_url_map" "default" {
  project         = google_project.project.project_id
  name            = "demo-lb"
  default_service = google_compute_backend_service.hello.id

  host_rule {
    hosts        = ["demo.reliably.com"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.hello.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.hello.id
    }

    path_rule {
      paths   = ["/noteboard", "/noteboard/", "/noteboard/*"]
      service = google_compute_backend_service.noteboard-frontend.id
    }

    path_rule {
      paths   = ["/noteboard/api/*"]
      service = google_compute_backend_service.noteboard-api.id
    }
  }
}

# resource "google_compute_backend_service" "gke" {
#   project    = google_project.project.project_id
#   name       = "gke"
#   enable_cdn = false

#   backend {
#     balancing_mode = "RATE"
#     max_rate       = 100
#     group          = google_compute_network_endpoint_group.gke.id
#   }


#   health_checks = [google_compute_health_check.gke-health-check.self_link]
# }

resource "google_compute_backend_service" "hello" {
  project    = google_project.project.project_id
  name       = "hello"
  enable_cdn = false

  backend {
    group = google_compute_region_network_endpoint_group.hello.id
  }
}

resource "google_compute_backend_service" "noteboard-frontend" {
  project    = google_project.project.project_id
  name       = "noteboard-frontend"
  enable_cdn = false

  backend {
    group = google_compute_region_network_endpoint_group.noteboard-frontend.id
  }
}

resource "google_compute_backend_service" "noteboard-api" {
  project    = google_project.project.project_id
  name       = "noteboard-api"
  enable_cdn = false

  backend {
    group = google_compute_region_network_endpoint_group.noteboard-api.id
  }
}

resource "google_compute_target_https_proxy" "demo" {
  provider         = google-beta
  project          = google_project.project.project_id
  depends_on       = [google_compute_url_map.default]
  name             = "demo"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
}


resource "google_compute_global_forwarding_rule" "demo" {
  provider   = google-beta
  project    = google_project.project.project_id
  depends_on = [google_compute_subnetwork.subnet]
  name       = "demo"

  ip_protocol           = "TCP"
  ip_address            = google_compute_global_address.default.address
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.demo.id
}

################################################################################
# Configure monitoring and our SLO for the services
################################################################################
resource "google_monitoring_custom_service" "hello" {
  project      = google_project.project.project_id
  display_name = "Hello service"

  telemetry {
    resource_name = google_cloud_run_service.hello.name
  }
}

resource "google_monitoring_slo" "hello_request_based_slo" {
  project      = google_project.project.project_id
  service      = google_monitoring_custom_service.hello.service_id
  display_name = "Terraform Test SLO with request based SLI (good total ratio)"

  goal                = 0.999
  rolling_period_days = 30

  request_based_sli {
    good_total_ratio {
      total_service_filter = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"demo-lb\""
      good_service_filter  = "metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\" resource.label.\"url_map_name\"=\"demo-lb\" metric.label.\"response_code_class\"<=\"499\""
    }
  }
}
