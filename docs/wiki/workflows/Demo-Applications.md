# Demo Applications

**Navigation:** [Home](../Home.md) > [Deployment Workflows](Deployment-Workflows.md) > Demo Applications

> **Quick Links:** [Google Boutique](#google-boutique-microservices)

---

## Overview

Demo applications to showcase HashiStack capabilities.

---

## Google Boutique Microservices

**Prerequisites:**
- Admin partitions configured
- GKE cluster with Consul deployed

### Deploy

```bash
task -t consul/admin-partitions/Taskfile.yml deploy-boutique-full
```

### Services Deployed

- **Frontend** - Web UI (port 8080)
- **Product Catalog** - Product inventory (port 3550)
- **Cart Service** - Shopping cart (port 7070)
- **Currency Service** - Currency conversion (port 7000)
- **Redis** - Cart storage (port 6379)

### Access

```bash
kubectl port-forward svc/frontend 8080:80 -n development
# Access at http://localhost:8080
```

---

**Previous:** [Task Automation Reference](Task-Automation-Reference.md) | **Next:** [Monitoring and Observability](../operations/Monitoring-and-Observability.md) | **[Back to Top](#demo-applications)**
