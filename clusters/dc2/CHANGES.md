# DC2 Cluster Configuration Changes

## Resource Naming Conflicts Fixed

The following resources were updated to use cluster-specific names to avoid conflicts with DC1:

### Network & Load Balancer Resources
- `google_compute_address.global-ip`: `lb-ip` → `${var.cluster_name}-lb-ip` 
- `google_compute_address.server_addr`: `server-addr-${count.index}` → `${var.cluster_name}-server-addr-${count.index}`
- `google_compute_address.client_addr`: `client-addr-${count.index}` → `${var.cluster_name}-client-addr-${count.index}`
- `google_compute_forwarding_rule.global-lb`: `hashistack-lb` → `${var.cluster_name}-hashistack-lb`
- `google_compute_forwarding_rule.clients-lb`: `clients-lb` → `${var.cluster_name}-clients-lb`

### Health Checks
- `google_compute_region_health_check.default`: `health-check` → `${var.cluster_name}-health-check`
- `google_compute_region_health_check.apps`: `health-check-apigw` → `${var.cluster_name}-health-check-apigw`
- `google_compute_health_check.http`: `http-health-check` → `${var.cluster_name}-http-health-check`

### Global HTTPS Resources
- `google_compute_global_address.https_ip`: `https-lb-ip` → `${var.cluster_name}-https-lb-ip`
- `google_compute_global_forwarding_rule.https-lb`: `https-forwarding-rule` → `${var.cluster_name}-https-forwarding-rule`
- `google_compute_target_https_proxy.https_proxy`: `https-proxy` → `${var.cluster_name}-https-proxy`
- `google_compute_url_map.https_lb`: `https-url-map` → `${var.cluster_name}-https-url-map`
- `google_compute_backend_service.https_backend`: `https-backend-service` → `${var.cluster_name}-https-backend-service`

### HTTP Redirect Resources
- `google_compute_url_map.http_redirect`: `http-redirect` → `${var.cluster_name}-http-redirect`
- `google_compute_target_http_proxy.http_proxy`: `http-proxy` → `${var.cluster_name}-http-proxy`
- `google_compute_global_forwarding_rule.http_redirect`: `http-redirect-rule` → `${var.cluster_name}-http-redirect-rule`

### SSL Certificate
- `google_compute_managed_ssl_certificate.monitoring_ssl`: `monitoring-ssl-cert` → `${var.cluster_name}-monitoring-ssl-cert`

### DNS Records
- `google_dns_record_set.dns`: `nomad.domain.com` → `nomad-${var.cluster_name}.domain.com`
- `google_dns_record_set.traefik`: `traefik.domain.com` → `traefik-${var.cluster_name}.domain.com`
- `google_dns_record_set.grafana`: `grafana.domain.com` → `grafana-${var.cluster_name}.domain.com`
- `google_dns_record_set.prometheus`: `prometheus.domain.com` → `prometheus-${var.cluster_name}.domain.com`
- `google_dns_record_set.consul`: `consul.domain.com` → `consul-${var.cluster_name}.domain.com`

### Network Configuration
- **Subnet CIDR**: Changed from `10.2.0.0/16` to `10.3.0.0/16` to avoid IP conflicts with DC1

## Result

With cluster_name = "gcp-dc2", the resources will be named:
- `gcp-dc2-lb-ip`, `gcp-dc2-https-lb-ip`, etc.
- DNS: `nomad-gcp-dc2.yourdomain.com`, `grafana-gcp-dc2.yourdomain.com`, etc.
- Network: `10.3.0.0/16` (vs DC1's `10.2.0.0/16`)

This ensures complete isolation between DC1 and DC2 clusters.