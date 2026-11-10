# Configuration

The package values cover the decisions most installations need to make: which functions to install, which managed resources to activate, observability, trust, and the corporate proxy. Everything else can still be customized in two ways.

## Container flags

The Crossplane core and the RBAC manager are configured via container flags. The package enables all the alpha features of Crossplane, computes some flags from the values (`--debug`), then merges `crossplane.args` and `rbac_manager.args` on top, so their flags take precedence. The flags are written without the leading dashes, and a flag set to `null` is removed.

```yaml
crossplane:
  args:
    max-concurrent-reconciles: 200
    poll-interval: 5m
rbac_manager:
  args:
    max-concurrent-reconciles: 20
```

An unknown flag prevents the controller from starting. Check the flags of the Crossplane version you install with `crossplane core start --help` and `crossplane rbac start --help`, or in the [source](https://github.com/crossplane/crossplane/tree/main/cmd/crossplane). A change rolls out the controller.

### Feature flags

The alpha features are disabled by default upstream, and enabled by the package:

| Flag | Feature |
|------|---------|
| `enable-dependency-version-upgrades` | Upgrade the dependencies of a package when it's updated |
| `enable-dependency-version-downgrades` | Downgrade the dependencies of a package when it's updated |
| `enable-signature-verification` | Verify the signatures of the packages via ImageConfigs (see [packages.md](packages.md#signature-verification)) |
| `enable-function-response-cache` | Cache the responses of the composition functions |
| `enable-operations` | Run Operations, CronOperations, and WatchOperations |
| `enable-pipeline-inspector` | Emit the data of the function pipeline runs to a sidecar |
| `enable-provider-deletion-protection` | Protect the providers from deletion while they have managed resources |

To disable one, set it to `null`:

```yaml
crossplane:
  args:
    enable-provider-deletion-protection: null
```

The beta features are enabled by default upstream. To disable one, set it to `false`, for example `enable-realtime-compositions: false`. See [feature flags](https://docs.crossplane.io/latest/get-started/install/#feature-flags).

### Vertical scaling

When reconciling many resources, increase the number of concurrent reconciliations (default: `100` for the core, `10` for the RBAC manager), together with the resources of the controllers (see [Resources](#resources)). Reduce how often the resources are checked for drift with `poll-interval` (default: `1m`) and `sync-interval` (default: `1h`). See [Crossplane pods](https://docs.crossplane.io/latest/guides/pods/).

## ytt overlays

Any Kubernetes resource of the package can be customized with a [ytt overlay](https://carvel.dev/ytt/docs/latest/ytt-overlays/). Store it in a Secret and reference it from the PackageInstall via the `ext.packaging.carvel.dev/ytt-paths-from-secret-name.0` annotation.

```shell
kubectl create secret generic crossplane-overlays -n kadras-system --from-file=overlays.yml
kubectl annotate packageinstall crossplane -n kadras-system \
  ext.packaging.carvel.dev/ytt-paths-from-secret-name.0=crossplane-overlays
```

The Crossplane core runs in the `crossplane` Deployment, and the RBAC manager in the `crossplane-rbac-manager` Deployment. Both run in a container named `crossplane`, after an init container named `crossplane-init`.

### Resources

The upstream Helm chart sets resource requests and limits for each controller. The controllers derive their Go memory limit (`GOMEMLIMIT`) from the memory limit, and their Go CPU limit (`GOMAXPROCS`) from the CPU limit, so keep both.

```yaml
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "crossplane"}})
---
spec:
  template:
    spec:
      containers:
        #@overlay/match by="name"
        - name: crossplane
          resources:
            limits:
              cpu: 1000m
              memory: 2Gi
```

### Caches

The Crossplane core caches the packages in an `emptyDir` volume limited to 20Mi (`package-cache`), and the function responses in one limited to 512Mi (`function-cache`). Increase the limits when installing many packages.

```yaml
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "crossplane"}})
---
spec:
  template:
    spec:
      volumes:
        #@overlay/match by="name"
        - name: package-cache
          emptyDir:
            sizeLimit: 100Mi
```

### Node placement

```yaml
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.subset({"kind": "Deployment"}), expects=2
---
spec:
  template:
    spec:
      #@overlay/match missing_ok=True
      nodeSelector:
        node-restriction.kubernetes.io/reserved-for: platform
      #@overlay/match missing_ok=True
      tolerations:
        - key: node-restriction.kubernetes.io/reserved-for
          operator: Equal
          value: platform
          effect: NoExecute
```

The providers and functions are deployed by Crossplane, not by the package: configure their placement with a DeploymentRuntimeConfig (see [packages.md](packages.md#runtime-configuration)).
