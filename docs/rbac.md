# Access to the Resources

The package extends the Kubernetes [default roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#user-facing-roles) with the composite resources, via [aggregation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/#aggregated-clusterroles). The users bound to `admin`, `edit`, or `view` in a namespace get the following permissions on the namespaced composite resources in that namespace, like the ones defined by the platform team for the applications.

| Resources | `admin`, `edit` | `view` |
|-----------|-----------------|--------|
| Namespaced composite resources | Read and write | Read |
| Managed resources | None | None |
| Compositions, CompositeResourceDefinitions, Providers, Functions, and the other cluster-scoped Crossplane resources | None | None |

The Crossplane RBAC manager creates the roles for the composite resources of each CompositeResourceDefinition, labelled for the Crossplane roles (`crossplane-admin`, `crossplane-edit`, `crossplane-view`). The package adds the `crossplane-composite-edit` and `crossplane-composite-view` ClusterRoles, which aggregate the roles of the composite resources and are aggregated to the Kubernetes default roles. Granting the Kubernetes default roles in a namespace is then enough to use the composite resources defined by the platform team.

The managed resources aren't included: they can reference cluster-wide provider configurations, which act with the permissions of the providers. Compose them via composite resources instead, or grant them explicitly with the Crossplane roles to trusted users.
