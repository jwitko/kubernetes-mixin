local mixin = import '../mixin.libsonnet';
std.manifestYamlDoc(std.get(mixin, 'prometheusRules', {}))
