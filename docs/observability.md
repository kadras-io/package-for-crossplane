# Observability

## Logs

The Crossplane core and the RBAC manager log at the `info` level. To troubleshoot them, enable the debug logs:

```yaml
observability:
  logging:
    level: debug
```

The Crossplane core also records Kubernetes events on the resources it reconciles. Check them, and the conditions of the resources, first: see [troubleshooting](https://docs.crossplane.io/latest/guides/troubleshoot-crossplane/). To enable the debug logs of a provider or function, use a DeploymentRuntimeConfig (see [packages.md](packages.md#runtime-configuration)).

## Metrics

The Crossplane core and the RBAC manager expose metrics in the Prometheus format on port 8080 (`/metrics`), on the `metrics` container port. Their Pods are annotated for Prometheus scraping (`prometheus.io/scrape`, `prometheus.io/port`, `prometheus.io/path`). To remove the annotations:

```yaml
observability:
  metrics:
    enabled: false
```

If you use the Prometheus Operator, create a PodMonitor instead:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: crossplane
  namespace: crossplane-system
spec:
  selector:
    matchExpressions:
      - key: app
        operator: In
        values: [crossplane, crossplane-rbac-manager]
  podMetricsEndpoints:
    - port: metrics
```

The Crossplane core exposes the duration of the function runs, the hits of the function response cache, the state of the circuit breakers of the composite resources, and the controller-runtime metrics. The providers expose metrics about their managed resources on port 8080 too: scrape them with a PodMonitor, or annotate their Pods via a DeploymentRuntimeConfig. See [metrics](https://docs.crossplane.io/latest/guides/metrics/).

## Change logs

Providers supporting it can log every change they make to the external resources. Enable it per provider with a DeploymentRuntimeConfig. See [change logs](https://docs.crossplane.io/latest/guides/change-logs/).
