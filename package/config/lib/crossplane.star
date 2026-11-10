load("@ytt:data", "data")
load("@ytt:struct", "struct")

# The namespace the upstream Helm chart is rendered into (see `task vendor`), replaced by the package namespace.
upstream_namespace = "crossplane-system"

# ###########
# COMPONENTS
# ###########

# The controllers in the upstream Helm chart. `key` is the name of their section in the values, `deployment`
# the name of their Deployment, and `service_account` the name of their ServiceAccount. Both run the Crossplane
# binary in a `crossplane` container, with a different subcommand, after a `crossplane-init` init container.
core = struct.encode({"key": "crossplane", "deployment": "crossplane", "service_account": "crossplane"})
rbac_manager = struct.encode({"key": "rbac_manager", "deployment": "crossplane-rbac-manager", "service_account": "rbac-manager"})
components = [core, rbac_manager]

container = "crossplane"
init_container = "crossplane-init"

# The port where the controllers expose metrics, as rendered from the upstream Helm chart.
metrics_port = 8080

# The labels selecting the Pods of a component, as defined in the upstream Helm chart.
def component_selector(component):
  return {"app": component.deployment, "release": "crossplane"}
end

# ###########
# FLAGS
# ###########

# The flags computed from the package values. `<component>.args` is merged on top of them.
def component_args(component):
  args = {}
  if data.values.observability.logging.level == "debug":
    args["debug"] = True
  end
  for name, value in struct.decode(getattr(data.values, component.key).args).items():
    args[name.lstrip("-")] = value
  end
  return args
end

# The arguments of the init container of the Crossplane core, which creates the CustomResourceDefinitions,
# the webhook configurations, and the default ManagedResourceActivationPolicy with the given activations.
def core_init_args():
  args = ["core", "init"]
  for activation in data.values.providers.default_activations:
    args.extend(["--activation", activation])
  end
  return args
end

def _format(value):
  if type(value) == "bool":
    return "true" if value else "false"
  end
  return str(value)
end

# Merges the given flags into the upstream arguments, keeping their order. The subcommand (`core start`, `rbac start`)
# stays first. New flags are appended, and flags set to null are removed. Upstream flags without a value,
# like `--enable-operations`, are kept as they are.
def _merge_args(upstream, overrides):
  subcommand = [arg for arg in upstream if not arg.startswith("-")]
  flags = {}
  for arg in upstream:
    if arg.startswith("-"):
      name, separator, value = arg.lstrip("-").partition("=")
      flags[name] = value if separator else None
    end
  end
  for name, value in overrides.items():
    if value == None:
      flags.pop(name, None)
    else:
      flags[name] = _format(value)
    end
  end
  return subcommand + ["--" + name if value == None else "--" + name + "=" + value for name, value in flags.items()]
end

# The `via` function of the overlays replacing the upstream container args.
def args_merger(overrides):
  return lambda left, _: _merge_args(left, overrides)
end
