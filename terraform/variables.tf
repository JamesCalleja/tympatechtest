variable "project_id" {
  description = "The GCP project ID where the GKE cluster will be created."
  type        = string
  default     = "tympahealth-james-calleja"
}

variable "region" {
  description = "The GCP region for the GKE cluster."
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "The GCP zone for the single-node GKE cluster."
  type        = string
  default     = "europe-west2-a"
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster."
  type        = string
  default     = "single-node-gke-cluster"
}

variable "tympa_gke_cluster_name" {
  description = "The name of the Tympa GKE cluster."
  type        = string
  default     = "tympa-gke-cluster"
}

variable "ip_cidr_range" {
  description = "The CIDR range for the GKE cluster's primary IP address."
  type        = string
  default     = "10.0.0.0/18"
}

variable "ip_range_pods" {
  description = "The IP range for the GKE cluster pods."
  type        = string
  default     = "10.0.64.0/19"
}
variable "ip_range_services" {
  description = "The IP range for the GKE cluster services."
  type        = string
  default     = "10.0.96.0/20"
}

variable "network" {
  description = "The name of the VPC network to use for the GKE cluster."
  type        = string
  default     = "tympa-network"
}

variable "subnetwork" {
  description = "The name of the subnetwork to use for the GKE cluster."
  type        = string
  default     = ""
}