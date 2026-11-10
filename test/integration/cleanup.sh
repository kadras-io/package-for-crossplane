#!/usr/bin/env bash
#
# Removes what uninstalling the package leaves behind on purpose: the Crossplane resources, their CustomResourceDefinitions
# (including the ones of the composite resources), the webhook configuration created at runtime, and the namespace.
# The finalizers are removed first, since Crossplane isn't running anymore to handle them.
#
#   ../cleanup.sh <crossplane-namespace>

set -eo pipefail

kubectl delete validatingwebhookconfiguration crossplane-no-usages --ignore-not-found

crds=$(kubectl get crds -o json | jq -r '.items[]
  | select((.metadata.name | endswith(".crossplane.io")) or any(.metadata.ownerReferences[]?; .kind == "CompositeResourceDefinition"))
  | .metadata.name')

for crd in $crds; do
  kubectl get "$crd" -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' |
    while read -r namespace name; do
      kubectl patch "$crd" "$name" ${namespace:+-n "$namespace"} --type=merge -p '{"metadata":{"finalizers":null}}'
    done
done
# shellcheck disable=SC2086
kubectl delete crds $crds --wait
kubectl delete namespace "$1" --wait
