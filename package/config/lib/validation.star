load("@ytt:regexp", "regexp")

# Validation helpers used by the values schema.
# They must not depend on data values, since they run while the schema is evaluated.

def is_dns_label(value):
  return len(value) <= 63 and regexp.match("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", value)
end
