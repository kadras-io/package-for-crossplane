# High Availability

The package runs 1 replica of the Crossplane core and of the RBAC manager, as recommended by Crossplane. Both use leader election, so additional replicas would only be standby, without improving the throughput: only the leader reconciles the resources. Instead:

* the controllers recover from a restart by reconciling the resources again, while the external resources and the composed resources keep existing;
* a PodDisruptionBudget with a single replica would block the node drains, so the package doesn't create one.

All the replicas of the Crossplane core serve its webhooks, which validate the Crossplane resources and protect the resources in use from deletion. To keep them available during a disruption of the Crossplane core, run 2 replicas with a ytt overlay (see [configuration.md](configuration.md#ytt-overlays)):

```yaml
#@ load("@ytt:overlay", "overlay")

#@overlay/match by=overlay.subset({"kind": "Deployment", "metadata": {"name": "crossplane"}})
---
spec:
  replicas: 2
```

To scale Crossplane, increase the concurrency and resources of the controllers ([vertical scaling](configuration.md#vertical-scaling)).

The providers and functions run 1 replica each by default. Configure them with a DeploymentRuntimeConfig (see [packages.md](packages.md#runtime-configuration)).
