# Crossplane

![Test Workflow](https://github.com/kadras-io/package-for-crossplane/actions/workflows/test.yml/badge.svg)
![Release Workflow](https://github.com/kadras-io/package-for-crossplane/actions/workflows/release.yml/badge.svg)
[![The SLSA Level 3 badge](https://slsa.dev/images/gh-badge-level3.svg)](https://slsa.dev/spec/v1.0/levels)
[![The Apache 2.0 license badge](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Follow us on Bluesky](https://img.shields.io/static/v1?label=Bluesky&message=Follow&color=1DA1F2)](https://bsky.app/profile/kadras.bsky.social)

A Carvel package for [Crossplane](https://crossplane.io), a Kubernetes extension that transforms your Kubernetes cluster into a universal control plane. It lets you compose cloud and Kubernetes resources into your own platform APIs, and manage them all through the Kubernetes API.

## ✨&nbsp; What's Included

* **Control plane**. The Crossplane core, running the package manager, the composition engine, and the webhooks, and the RBAC manager. All the alpha features are enabled, and each controller can be configured via its flags.
* **Composition functions**. The [patch-and-transform](https://github.com/crossplane-contrib/function-patch-and-transform), [KCL](https://github.com/crossplane-contrib/function-kcl), [kro](https://github.com/crossplane-contrib/function-kro), and [Pythonic](https://github.com/crossplane-contrib/function-pythonic) functions, installed by default, and the optional auto-ready, CEL filter, extra resources, sequencer, shell, and status transformer functions. Each one can be enabled or disabled.
* **Providers**. Configurable activation of the managed resources, to only create the CustomResourceDefinitions you use.
* **Observability**. Debug logs on demand, and metrics annotated for Prometheus scraping.
* **Security**. The controllers, providers, and functions comply with the `restricted` [Pod Security Standard](https://kubernetes.io/docs/concepts/security/pod-security-standards/), enforced on their namespace, and the controllers mount short-lived service account tokens.

## 🚀&nbsp; Getting Started

### Prerequisites

* Kubernetes 1.34+
* Carvel [`kctrl`](https://carvel.dev/kapp-controller/docs/latest/install/#installing-kapp-controller-cli-kctrl) CLI.
* Carvel [kapp-controller](https://carvel.dev/kapp-controller) deployed in your Kubernetes cluster. You can install it with Carvel [`kapp`](https://carvel.dev/kapp/docs/latest/install) (recommended choice) or `kubectl`.

```shell
kapp deploy -a kapp-controller -y \
  -f https://github.com/carvel-dev/kapp-controller/releases/latest/download/release.yml
```

### Dependencies

Crossplane has no required dependencies. To authenticate with private registries, install [secretgen-controller](https://github.com/kadras-io/package-for-secretgen-controller) from the [Kadras package repository](https://github.com/kadras-io/kadras-packages).

### Installation

Add the Kadras [package repository](https://github.com/kadras-io/kadras-packages) to your Kubernetes cluster:

```shell
kctrl package repository add -r kadras-packages \
  --url ghcr.io/kadras-io/kadras-packages \
  -n kadras-system --create-namespace
```

<details><summary>Installation without package repository</summary>
The recommended way of installing the Crossplane package is via the Kadras <a href="https://github.com/kadras-io/kadras-packages">package repository</a>. If you prefer not using the repository, you can add the package definition directly using <a href="https://carvel.dev/kapp/docs/latest/install"><code>kapp</code></a> or <code>kubectl</code>.

```shell
kubectl create namespace kadras-system
kapp deploy -a crossplane-package -n kadras-system -y \
  -f https://github.com/kadras-io/package-for-crossplane/releases/latest/download/metadata.yml \
  -f https://github.com/kadras-io/package-for-crossplane/releases/latest/download/package.yml
```
</details>

Install the Crossplane package:

```shell
kctrl package install -i crossplane \
  -p crossplane.packages.kadras.io \
  -v ${VERSION} \
  -n kadras-system
```

> **Note**
> You can find the `${VERSION}` value by retrieving the list of package versions available in the Kadras package repository installed on your cluster.
> 
> ```shell
> kctrl package available list -p crossplane.packages.kadras.io -n kadras-system
> ```

Verify the installed packages and their status:

```shell
kctrl package installed list -n kadras-system
```

### Try It Out

Define an `App` API, composed of a Deployment and a Service with the patch-and-transform function. Crossplane needs permissions on the resources it composes, granted via an aggregated ClusterRole.

```shell
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: crossplane:compose-apps
  labels:
    rbac.crossplane.io/aggregate-to-crossplane: "true"
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["*"]
---
apiVersion: apiextensions.crossplane.io/v2
kind: CompositeResourceDefinition
metadata:
  name: apps.example.kadras.io
spec:
  scope: Namespaced
  group: example.kadras.io
  names:
    kind: App
    plural: apps
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
            required:
            - image
---
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: apps
spec:
  compositeTypeRef:
    apiVersion: example.kadras.io/v1alpha1
    kind: App
  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
      - name: deployment
        base:
          apiVersion: apps/v1
          kind: Deployment
          spec:
            replicas: 1
            template:
              spec:
                containers:
                - name: app
                  ports:
                  - containerPort: 9898
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.image
          toFieldPath: spec.template.spec.containers[0].image
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.selector.matchLabels[app.kubernetes.io/name]
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.template.metadata.labels[app.kubernetes.io/name]
        readinessChecks:
        - type: MatchCondition
          matchCondition:
            type: Available
            status: "True"
      - name: service
        base:
          apiVersion: v1
          kind: Service
          spec:
            ports:
            - port: 80
              targetPort: 9898
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.selector[app.kubernetes.io/name]
        readinessChecks:
        - type: None
EOF
```

Create an `App` running [podinfo](https://github.com/stefanprodan/podinfo):

```shell
kubectl apply -f - <<EOF
apiVersion: example.kadras.io/v1alpha1
kind: App
metadata:
  name: podinfo
  namespace: default
spec:
  image: ghcr.io/stefanprodan/podinfo:6.17.0
EOF
```

Check that the `App` is ready, and the resources Crossplane composed for it:

```shell
kubectl get app.example.kadras.io podinfo -n default
kubectl get deployments,services -n default -l crossplane.io/composite=podinfo
```

## 📙&nbsp; Documentation

Documentation, tutorials and examples for this package are available in the [docs](docs) folder.
For documentation specific to Crossplane, check out [docs.crossplane.io](https://docs.crossplane.io).

Features:

* [Packages: providers, functions, and configurations](docs/packages.md)
* [High availability](docs/high-availability.md)
* [Observability](docs/observability.md)
* [Security](docs/security.md)

Operations:

* [Configuration and ytt overlays](docs/configuration.md)
* [Corporate proxy](docs/corporate-proxy.md)
* [Custom certificate authorities](docs/custom-ca.md)
* [Upgrading and uninstalling](docs/upgrade.md)
* [Verifying the release](docs/verify-release.md)

## 🎯&nbsp; Configuration

The Crossplane package can be customized via a `values.yml` file.

```yaml
providers:
  default_activations:
    - "*.kubernetes.m.crossplane.io"
functions:
  kcl:
    enabled: false
observability:
  logging:
    level: debug
```

Reference the `values.yml` file from the `kctrl` command when installing or upgrading the package.

```shell
kctrl package install -i crossplane \
  -p crossplane.packages.kadras.io \
  -v ${VERSION} \
  -n kadras-system \
  --values-file values.yml
```

Anything not covered by the values can be customized via container flags or ytt overlays, as described in [docs/configuration.md](docs/configuration.md).

### Values

The Crossplane package has the following configurable properties.

<details><summary>Configurable properties</summary>

<!-- values-table:start -->

| Config | Default | Description |
|--------|---------|-------------|
| `namespace` | `"crossplane-system"` | The namespace in which to deploy Crossplane. Crossplane also deploys the providers and functions there. |
| `crossplane.args` | `{}` | Container flags, merged on top of the ones computed by the package, which enable all the alpha features. Set a flag to null to remove it. See https://docs.crossplane.io/latest/get-started/install/#feature-flags. |
| `rbac_manager.args` | `{}` | Container flags, merged on top of the ones computed by the package. Set a flag to null to remove it. |
| `providers.default_activations` | `["*"]` | The activations of the default ManagedResourceActivationPolicy, created at startup: the managed resource kinds of the providers to activate, as patterns like `*.aws.m.upbound.io`. Activate only the ones you use to reduce the CustomResourceDefinitions in the cluster, or set no activation to manage the policies yourself. |
| `functions.auto_ready.enabled` | `false` | Whether to install the function. |
| `functions.cel_filter.enabled` | `false` | Whether to install the function. |
| `functions.extra_resources.enabled` | `false` | Whether to install the function. |
| `functions.kcl.enabled` | `true` | Whether to install the function. |
| `functions.kro.enabled` | `true` | Whether to install the function. |
| `functions.patch_and_transform.enabled` | `true` | Whether to install the function. |
| `functions.pythonic.enabled` | `true` | Whether to install the function. |
| `functions.sequencer.enabled` | `false` | Whether to install the function. |
| `functions.shell.enabled` | `false` | Whether to install the function. |
| `functions.status_transformer.enabled` | `false` | Whether to install the function. |
| `ca_cert_data` | `""` | PEM-encoded certificates of additional certificate authorities to trust when pulling packages, for example from a private OCI registry. The system ones are still trusted. |
| `observability.logging.level` | `"info"` | The log level of the controllers. |
| `observability.metrics.enabled` | `true` | Whether to annotate the Pods for Prometheus scraping. The controllers always expose metrics on port 8080 (`/metrics`). |
| `proxy.http_proxy` | `""` | The HTTP proxy to use for network traffic. |
| `proxy.https_proxy` | `""` | The HTTPS proxy to use for network traffic. |
| `proxy.no_proxy` | `""` | A comma-separated list of hostnames, IP addresses, or IP ranges in CIDR format that should not use the proxy. Include the in-cluster domains, since Crossplane calls the functions over the cluster network. |

<!-- values-table:end -->

</details>

## 🛠️&nbsp; Development

The development environment is defined with [devenv](https://devenv.sh). Enter it with `devenv shell`, or automatically with [direnv](https://direnv.net) after running `direnv allow`. Run `task --list` to see all the available tasks.

```shell
# Run the unit tests, which render the package and check the result without a cluster.
task test:config

# Create a local kind cluster and run the integration tests on it.
task cluster:setup
task test:integration

# Deploy the package from the local sources to the current cluster.
task dev

# Vendor a new version of the upstream Helm chart and CRDs (set in package/vendir.yml) and render the chart into the package.
task vendor

# Update the table of configurable values in this README after changing the values schema.
task docs:values
```

The upstream Helm chart is rendered at vendoring time into `package/config/upstream`, with the values fixed for the package in `package/helm/values.yml`. The CustomResourceDefinitions, which Crossplane creates at runtime, are vendored next to it, so that the package can include Crossplane resources like the functions. The configurable values are applied on top via ytt overlays, so the package is rendered with ytt only. The unit tests are described in [test/unit/README.md](test/unit/README.md).

## 🛡️&nbsp; Security

The security process for reporting vulnerabilities is described in [SECURITY.md](SECURITY.md).

## 🖊️&nbsp; License

This project is licensed under the **Apache License 2.0**. See [LICENSE](LICENSE) for more information.
