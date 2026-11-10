# Custom Certificate Authorities

If Crossplane needs to pull packages from a registry with a certificate signed by a private certificate authority, add the PEM-encoded certificates of the authority to the package values.

```yaml
ca_cert_data: |
  -----BEGIN CERTIFICATE-----
  MIICvjCCAaYCCQDhcJuwMw6yZzANBgkqhkiG9w0BAQsFADAhMQswCQYDVQQGEwJE
  ...
  -----END CERTIFICATE-----
```

The certificates are stored in the `crossplane-ca-certificates` ConfigMap and mounted in the Crossplane core, which trusts them in addition to the system certificate authorities when pulling packages. It's the same as the `registryCaBundleConfig` value of the upstream Helm chart.

The providers and functions don't get them: if they reach services with certificates signed by a private certificate authority, mount them via a DeploymentRuntimeConfig (see [packages.md](packages.md#runtime-configuration)).
