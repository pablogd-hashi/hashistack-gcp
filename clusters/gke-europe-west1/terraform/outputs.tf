output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "GKE cluster location (region)"
  value       = google_container_cluster.primary.location
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "kubernetes_cluster_name" {
  description = "GKE cluster name for kubectl"
  value       = google_container_cluster.primary.name
}

output "kubernetes_cluster_host" {
  description = "GKE cluster host"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "gke_auth_command" {
  description = "Command to authenticate with the GKE cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.gcp_project}"
}

output "cluster_info" {
  description = "Cluster information"
  value = {
    cluster_name     = google_container_cluster.primary.name
    location         = google_container_cluster.primary.location
    node_count       = var.node_count
    machine_type     = var.gcp_instance
    network          = google_compute_network.gke_network.name
    subnetwork       = google_compute_subnetwork.gke_subnet.name
  }
}

output "network_info" {
  description = "Network information"
  value = {
    network_name     = google_compute_network.gke_network.name
    subnet_name      = google_compute_subnetwork.gke_subnet.name
    subnet_cidr      = google_compute_subnetwork.gke_subnet.ip_cidr_range
    pods_cidr        = "10.11.0.0/16"
    services_cidr    = "10.12.0.0/16"
  }
}

output "kubectl_commands" {
  description = "Useful kubectl commands"
  value = {
    auth_command = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region ${google_container_cluster.primary.location} --project ${var.gcp_project}"
    get_nodes    = "kubectl get nodes"
    get_pods     = "kubectl get pods --all-namespaces"
    get_services = "kubectl get services --all-namespaces"
  }
}