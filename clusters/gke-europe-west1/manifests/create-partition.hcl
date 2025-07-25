# Admin Partition Configuration for GKE
# Run this on a Consul server to create the new partition

# Create the admin partition
partition "gke-europe-west1" {
  description = "Admin partition for GKE cluster in europe-west1"
}