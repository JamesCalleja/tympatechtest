# Enable necessary Google APIs
resource "google_project_service" "container_api" {
  project            = var.project_id
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

# Create a new VPC network for the GKE cluster
resource "google_compute_network" "gke_vpc" {
  project                 = var.project_id
  name                    = "${var.gke_cluster_name}-vpc"
  auto_create_subnetworks = false # We will explicitly create subnets
  routing_mode            = "REGIONAL"
}

# Create a subnetwork within the new VPC network
resource "google_compute_subnetwork" "gke_subnetwork" {
  project       = var.project_id
  name          = "${var.gke_cluster_name}-subnet"
  ip_cidr_range = var.ip_cidr_range # Subnet for a dedicated subnet (65536 addresses)
  region        = var.region
  network       = google_compute_network.gke_vpc.name

  # Secondary IP range for Pods
  secondary_ip_range {
    range_name    = "gke-pods-range"
    ip_cidr_range = var.ip_range_pods # Subnet for pods (8192 addresses)
  }

  # Secondary IP range for Services
  secondary_ip_range {
    range_name    = "gke-services-range"
    ip_cidr_range = var.ip_range_services # Subnet for services (4096 addresses)
  }
}


# --- GKE Cluster Module Configuration ---

module "gke_cluster" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "36.3.0"

  deletion_protection = false

  project_id = var.project_id
  name       = var.gke_cluster_name
  region     = var.region

  network           = "${var.gke_cluster_name}-vpc"
  subnetwork        = google_compute_subnetwork.gke_subnetwork.name
  ip_range_pods     = google_compute_subnetwork.gke_subnetwork.secondary_ip_range[0].range_name # Corresponds to "gke-pods-range"
  ip_range_services = google_compute_subnetwork.gke_subnetwork.secondary_ip_range[1].range_name # Corresponds to "gke-services-range"

  # For a single-node cluster, we define a single node pool with node_count = 1
  remove_default_node_pool = true
  node_pools = [
    {
      name               = "single-node-pool"
      machine_type       = "e2-large"
      initial_node_count = 1
      min_node_count     = 1
      max_node_count     = 1
      disk_size_gb       = 50
      disk_type          = "pd-standard"
      image_type         = "COS_CONTAINERD"
      auto_repair        = true
      auto_upgrade       = true
      local_ssd_count    = 0
    }
  ]
}
