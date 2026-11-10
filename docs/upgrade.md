# Upgrading

Upgrade Crossplane one minor version at a time, using the most recent patch version of each, and read the [upgrade guide](https://docs.crossplane.io/latest/guides/upgrade-crossplane/) and the [release notes](https://github.com/crossplane/crossplane/releases) of each version first.

```shell
kctrl package installed update -i crossplane -v ${VERSION} -n kadras-system
```

## Uninstalling

The Crossplane resources have finalizers, handled by Crossplane and the providers while they run: deleting a managed resource deletes the external resource it represents. Uninstalling the package doesn't delete them. Like `helm uninstall`, it keeps the CustomResourceDefinitions, the namespace, and the `default` DeploymentRuntimeConfig, with all the Crossplane resources, the providers, and the resources they manage, and only deletes the controllers and the functions of the package. Installing the package again resumes the reconciliation.

Crossplane creates the `crossplane-no-usages` ValidatingWebhookConfiguration at runtime, so uninstalling the package doesn't delete it either. Until Crossplane is installed again, it blocks the deletion of the resources in use by a Usage (labelled `crossplane.io/in-use: "true"`).

To remove Crossplane completely, follow the [uninstall guide](https://docs.crossplane.io/latest/guides/uninstall-crossplane/) before uninstalling the package, while Crossplane still runs: delete the composite resource definitions, the remaining managed resources, the configurations, and the providers. Then, uninstall the package, and delete what it kept:

```shell
kubectl delete validatingwebhookconfiguration crossplane-no-usages
kubectl get crd -o name | grep crossplane.io | xargs kubectl delete
kubectl delete namespace crossplane-system
```

Deleting the CustomResourceDefinitions deletes all the resources of that type: if some still exist, they're stuck on their finalizers, since Crossplane isn't running to handle them.
