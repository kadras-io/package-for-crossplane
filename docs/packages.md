# Packages

Crossplane extends the cluster with packages, pulled from OCI registries and deployed in the package namespace: providers, which manage external resources; functions, which run the composition pipelines; and configurations, which bundle APIs and compositions. See [packages](https://docs.crossplane.io/latest/packages/).

## Functions

The package can install these composition functions from [crossplane-contrib](https://github.com/crossplane-contrib). Each one runs in its own Pod.

| Value | Default | Function |
|-------|---------|----------|
| `functions.patch_and_transform` | enabled | [function-patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform), to compose resources with patches and transforms |
| `functions.kcl` | enabled | [function-kcl](https://github.com/crossplane-contrib/function-kcl), to compose resources with [KCL](https://www.kcl-lang.io) |
| `functions.kro` | enabled | [function-kro](https://github.com/crossplane-contrib/function-kro), to compose resources with [kro](https://kro.run) ResourceGraphDefinitions |
| `functions.pythonic` | enabled | [function-pythonic](https://github.com/crossplane-contrib/function-pythonic), to compose resources with Python |
| `functions.auto_ready` | disabled | [function-auto-ready](https://github.com/crossplane-contrib/function-auto-ready), to detect the composed resources that are ready, so that the composite resource becomes ready when all of them are |
| `functions.cel_filter` | disabled | [function-cel-filter](https://github.com/crossplane-contrib/function-cel-filter), to filter the composed resources with [CEL](https://cel.dev) expressions |
| `functions.extra_resources` | disabled | [function-extra-resources](https://github.com/crossplane-contrib/function-extra-resources), to select existing resources from the cluster for the next functions of the pipeline |
| `functions.sequencer` | disabled | [function-sequencer](https://github.com/crossplane-contrib/function-sequencer), to delay the creation of composed resources until other ones are ready |
| `functions.shell` | disabled | [function-shell](https://github.com/crossplane-contrib/function-shell), to run shell commands and write their output to fields of the composite resource |
| `functions.status_transformer` | disabled | [function-status-transformer](https://github.com/crossplane-contrib/function-status-transformer), to set status conditions on the composite resource by matching the ones of the composed resources |

```yaml
functions:
  kro:
    enabled: false
  auto_ready:
    enabled: true
  sequencer:
    enabled: true
```

function-shell runs arbitrary commands, written in the compositions, in its Pod: enable it only if you trust the authors of all the compositions in the cluster.

Install other functions with a `Function` resource. The functions of the package are installed after Crossplane, and deleted before it on uninstall, while Crossplane can still remove their Pods.

## Providers

Install providers with a `Provider` resource. Each provider defines its managed resources with ManagedResourceDefinitions, and only creates the CustomResourceDefinitions of the active ones, as selected by the ManagedResourceActivationPolicies. At startup, Crossplane creates the `default` policy, which activates all of them. Activate only the managed resources you use, to reduce the load on the Kubernetes API server:

```yaml
providers:
  default_activations:
    - "*.kubernetes.m.crossplane.io"
    - "buckets.s3.aws.m.upbound.io"
```

With no activations, the `default` policy isn't created, so that you can manage the policies yourself. Crossplane doesn't update the `default` policy if it already exists, so a change of `providers.default_activations` only applies to new installations: afterwards, edit the policy directly. See [managed resource activation policies](https://docs.crossplane.io/latest/managed-resources/managed-resource-activation-policies/).

## Runtime configuration

The providers and functions run with the `default` DeploymentRuntimeConfig, unless they reference another one via `spec.runtimeConfigRef`. The package creates it, so that their Pods comply with the `restricted` Pod Security Standard enforced on the package namespace (see [security.md](security.md#pod-security-standards)). It's managed by the package: to customize the runtime of a provider or function, for example its resources or flags, create your own DeploymentRuntimeConfig, with the same security context, and reference it. See [runtime configuration](https://docs.crossplane.io/latest/packages/providers/#runtime-configuration).

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: debug
spec:
  deploymentTemplate:
    spec:
      selector: {}
      template:
        spec:
          securityContext:
            runAsNonRoot: true
            runAsUser: 2000
            runAsGroup: 2000
            seccompProfile:
              type: RuntimeDefault
          containers:
          - name: package-runtime
            args:
            - --debug
            securityContext:
              runAsNonRoot: true
              runAsUser: 2000
              runAsGroup: 2000
              allowPrivilegeEscalation: false
              privileged: false
              capabilities:
                drop:
                - ALL
```

## Private registries

The package creates the `canonical-registry-credentials` Secret in its namespace, populated by [secretgen-controller](https://github.com/kadras-io/package-for-secretgen-controller) with the credentials exported to it. The controllers use it to pull their images, and the functions of the package to pull their packages. Reference it from your providers, functions, and configurations via `spec.packagePullSecrets`, or for all the packages from a registry via an [ImageConfig](https://docs.crossplane.io/latest/packages/image-configs/):

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: ImageConfig
metadata:
  name: private-registry
spec:
  matchImages:
    - prefix: registry.example.com
  registry:
    authentication:
      pullSecretRef:
        name: canonical-registry-credentials
```

An ImageConfig can also rewrite the images of a registry to a mirror, for air-gapped installations. If the registry uses a certificate signed by a private certificate authority, see [custom-ca.md](custom-ca.md).

## Signature verification

The signature verification of the packages is enabled (`--enable-signature-verification`). Configure it per registry with an ImageConfig, for example to only install the packages of your organization signed with Cosign keyless by its release workflows on GitHub Actions:

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: ImageConfig
metadata:
  name: verify-my-org
spec:
  matchImages:
    - prefix: registry.example.com/my-org
  verification:
    provider: Cosign
    cosign:
      authorities:
        - name: my-org
          keyless:
            identities:
              - issuer: https://token.actions.githubusercontent.com
                subjectRegExp: ^https://github\.com/my-org/.*$
```

The result is reported in the `Verified` condition of the package revisions. See [image configs](https://docs.crossplane.io/latest/packages/image-configs/).
