# Corporate Proxy

When running Crossplane behind a corporate proxy, configure the Crossplane core to pull the packages from the OCI registries through it.

```yaml
proxy:
  https_proxy: http://proxy.example.com:3128
  no_proxy: .cluster.local.,.cluster.local,.svc,10.0.0.0/8
```

The Crossplane core talks to the Kubernetes API server and calls the functions over the cluster network, so include their addresses in `no_proxy`, together with the Pod and Service networks, so that the cluster traffic doesn't go through the proxy.

The providers and functions don't get these settings. If they reach external services, like cloud provider APIs, set the proxy environment variables via a DeploymentRuntimeConfig (see [packages.md](packages.md#runtime-configuration)).
