# HashiStack GCP Wiki Documentation

This directory contains wiki-style documentation for the HashiStack GCP deployment project.

## Documentation Structure

The documentation is organized into logical categories for easy navigation:

### Getting Started
- [Home](Home.md) - Main documentation hub
- [Prerequisites and Setup](getting-started/Prerequisites-and-Setup.md) - Install tools and configure GCP
- [Quick Start Guide](getting-started/Quick-Start-Guide.md) - Deploy your first cluster in 30 minutes
- [Architecture Overview](getting-started/Architecture-Overview.md) - *Coming soon*

### Core Infrastructure
- [Image Building with Packer](infrastructure/Image-Building-with-Packer.md) - *Coming soon*
- [VM Cluster Deployment](infrastructure/VM-Cluster-Deployment.md) - *Coming soon*
- [GKE Cluster Deployment](infrastructure/GKE-Cluster-Deployment.md) - *Coming soon*
- [OpenShift Integration](infrastructure/OpenShift-Integration.md) - *Coming soon*
- [Secure Access with Boundary](infrastructure/Secure-Access-with-Boundary.md) - *Coming soon*

### Advanced Features
- [Admin Partitions](advanced-features/Admin-Partitions.md) - *Coming soon*
- [Cluster Peering](advanced-features/Cluster-Peering.md) - *Coming soon*
- [Consul-Terraform-Sync](advanced-features/Consul-Terraform-Sync.md) - *Coming soon*
- [Service Intentions](advanced-features/Service-Intentions.md) - *Coming soon*

### Deployment Workflows
- [Deployment Workflows](workflows/Deployment-Workflows.md) - *Coming soon*
- [Task Automation Reference](workflows/Task-Automation-Reference.md) - *Coming soon*
- [Demo Applications](workflows/Demo-Applications.md) - *Coming soon*

### Operations
- [Monitoring and Observability](operations/Monitoring-and-Observability.md) - *Coming soon*
- [Troubleshooting Guide](operations/Troubleshooting-Guide.md) - *Coming soon*
- [Maintenance and Cleanup](operations/Maintenance-and-Cleanup.md) - *Coming soon*

## Quick Start

New to this project? Start here:

1. **[Home](Home.md)** - Overview and navigation
2. **[Prerequisites](getting-started/Prerequisites-and-Setup.md)** - Setup your environment
3. **[Quick Start](getting-started/Quick-Start-Guide.md)** - Deploy in 5 steps

## Migration Status

This wiki is currently under development, migrating content from existing README files.

### Completed Pages
- Home
- Prerequisites and Setup
- Quick Start Guide

### In Progress
- Architecture Overview
- Image Building with Packer
- VM Cluster Deployment
- Admin Partitions

### Planned
- All remaining infrastructure pages
- Advanced features documentation
- Workflow guides
- Operations documentation

## Original Documentation

Until migration is complete, original README files remain available:

- [Main README](../../../README.md)
- [Packer README](../../../packer/gcp/README.md)
- [Boundary README](../../../boundary/README.md)
- [Admin Partitions README](../../../consul/admin-partitions/README.md)
- [Cluster Peering README](../../../consul/peering/README.md)

## Contributing

When adding or updating documentation:

1. Follow the established page template (see existing pages)
2. Include navigation breadcrumbs at the top
3. Add cross-references to related pages
4. Use consistent heading hierarchy (H1 for title, H2 for sections, H3 for subsections)
5. Include code examples with proper syntax highlighting
6. Add "Previous | Next" navigation at the bottom

## Page Template

```markdown
# Page Title

**Navigation:** [Home](../Home.md) > [Category](Category-Page.md) > Current Page

> **Quick Links:** [Section 1](#section-1) | [Section 2](#section-2)

---

## Overview

Brief introduction...

## Main Content Sections

...

## Related Pages

- [Related Page 1](../path/to/page.md)
- [Related Page 2](../path/to/page.md)

---

**Previous:** [Page Name](Previous-Page.md) | **Next:** [Page Name](Next-Page.md) | **[Back to Top](#page-title)**
```

## Questions or Issues?

- Check the [Troubleshooting Guide](operations/Troubleshooting-Guide.md) (when available)
- Review original READMEs in the project root
- Open an issue in the GitHub repository
