# Maintenance and Cleanup

**Navigation:** [Home](../Home.md) > [Operations](Monitoring-and-Observability.md) > Maintenance and Cleanup

> **Quick Links:** [Cleanup](#cleanup-procedures) | [Upgrade](#upgrade-procedures) | [Backup](#backup-strategies)

---

## Overview

Procedures for maintaining and cleaning up your HashiStack deployment.

---

## Cleanup Procedures

### Destroy Single Datacenter

```bash
# Destroy DC1
task destroy-dc1

# Destroy DC2
task destroy-dc2
```

### Destroy GKE Clusters

```bash
cd clusters/gke-europe-west1/terraform
terraform destroy

cd clusters/gke-southwest/terraform
terraform destroy
```

### Clean Up Packer Images

```bash
# List images
gcloud compute images list --filter="family=hashistack"

# Delete old images
gcloud compute images delete IMAGE_NAME --quiet

# Keep only latest 2-3 images
gcloud compute images list \
  --filter="family=hashistack" \
  --sort-by="~creationTimestamp" \
  --format="value(name)" \
  | tail -n +4 \
  | xargs -I {} gcloud compute images delete {} --quiet
```

---

## Upgrade Procedures

### Upgrade Consul/Nomad

1. Build new Packer images with updated versions
2. Update `consul_version` and `nomad_version` in variables
3. Re-run `task build-images`
4. Rolling update servers (one at a time)
5. Update clients

### Upgrade GKE

```bash
# Upgrade via Terraform
cd clusters/gke-europe-west1/terraform
terraform plan  # Review k8s version changes
terraform apply
```

---

## Backup Strategies

### Consul Backups

```bash
# Create snapshot
consul snapshot save backup.snap

# Restore snapshot
consul snapshot restore backup.snap
```

### Nomad Backups

```bash
# Export job specifications
nomad job inspect JOB_NAME > job-backup.json

# Restore
nomad job run job-backup.json
```

---

## Cost Optimization

**Reduce costs:**
- Destroy unused environments
- Scale down GKE node pools
- Delete old Packer images
- Use preemptible VMs for dev/test

---

**Previous:** [Monitoring and Observability](Monitoring-and-Observability.md) | **[Back to Home](../Home.md)** | **[Back to Top](#maintenance-and-cleanup)**
