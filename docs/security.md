# Security

## Pod Security Standards

The `restricted` [Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/) is enforced on the package namespace, where Crossplane also deploys the providers and functions.

* The Crossplane core and the RBAC manager run as non-root, with a read-only root filesystem, no privilege escalation, no capabilities, and the `RuntimeDefault` seccomp profile. Upstream doesn't drop the capabilities or set the seccomp profile.
* The providers and functions run with the `default` DeploymentRuntimeConfig, created by the package: they run as non-root, with no privilege escalation, no capabilities, and the `RuntimeDefault` seccomp profile. Upstream doesn't drop the capabilities or set the seccomp profile either. Your own DeploymentRuntimeConfigs need the same settings (see [packages.md](packages.md#runtime-configuration)).

## Service account tokens

The service account tokens of the controllers aren't auto-mounted. The containers and init containers of the Crossplane core and the RBAC manager mount a projected token instead, which expires after an hour and is rotated by the kubelet.

## Permissions

Crossplane manages the CustomResourceDefinitions of the composite and managed resources, and the RBAC manager grants Crossplane and the providers the permissions on them. Crossplane needs permissions on any other resource it composes, like Deployments: grant them with a ClusterRole labelled `rbac.crossplane.io/aggregate-to-crossplane: "true"`, as in the [README](../README.md#try-it-out).

The `crossplane-admin`, `crossplane-edit`, `crossplane-view`, and `crossplane-browse` ClusterRoles grant access to the Crossplane resources. The RBAC manager also creates ClusterRoles for the composite resources of each CompositeResourceDefinition, aggregated to them. Bind them to your users: only `crossplane-admin` is bound, to the `crossplane:masters` group. See [Crossplane pods](https://docs.crossplane.io/latest/guides/pods/).

The providers can only request the permissions allowed by the `crossplane:allowed-provider-permissions` ClusterRole.

## Image signatures

The Crossplane images aren't signed, so the package doesn't include Kyverno policies verifying them. The package itself is signed and comes with a SLSA provenance attestation (see [verify-release.md](verify-release.md)).

Crossplane can verify the signatures of the providers, functions, and configurations it installs, as described in [packages.md](packages.md#signature-verification).
