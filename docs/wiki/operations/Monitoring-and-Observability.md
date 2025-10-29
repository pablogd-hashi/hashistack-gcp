# Monitoring and Observability

**Navigation:** [Home](../Home.md) > [Operations](Monitoring-and-Observability.md) > Monitoring and Observability

> **Quick Links:** [Prerequisites](#prerequisites) | [Deploy Stack](#deploy-monitoring-stack) | [Dashboards](#access-dashboards)

---

## Overview

Deploy Prometheus and Grafana for monitoring Consul and Nomad clusters.

**Prerequisites:**
- [VM Cluster Deployment](../infrastructure/VM-Cluster-Deployment.md) - DC1 deployed

---

## Deploy Monitoring Stack

```bash
# Deploy Prometheus + Grafana to DC1
task deploy-monitoring-dc1

# Or for DC2
task deploy-monitoring-dc2
```

This deploys:
- Prometheus (metrics collection)
- Grafana (visualization)
- Pre-configured dashboards for Consul/Nomad

---

## Access Dashboards

### Grafana

```bash
# Get client IP
terraform -chdir=clusters/dc1/terraform output nomad_client_ips

# Access Grafana
http://<client-ip>:3000

# Default credentials
Username: admin
Password: admin
```

### Prometheus

```bash
# Access Prometheus
http://<client-ip>:9090
```

---

## Available Dashboards

**Consul:**
- Server health and performance
- Service mesh metrics
- API request rates

**Nomad:**
- Job status and allocation
- Resource utilization
- Task performance

---

## Metrics Endpoints

**Consul metrics:** `http://<server-ip>:8500/v1/agent/metrics`

**Nomad metrics:** `http://<server-ip>:4646/v1/metrics`

---

**Previous:** [Demo Applications](../workflows/Demo-Applications.md) | **Next:** [Maintenance and Cleanup](Maintenance-and-Cleanup.md) | **[Back to Top](#monitoring-and-observability)**
