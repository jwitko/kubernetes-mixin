// Import the main mixin which aggregates everything
local mixin = import '../mixin.libsonnet';
// Import utils for helper functions
local utils = import '../lib/utils.libsonnet';

// Make sure configuration has necessary defaults
local config = mixin._config {
  showMultiCluster: if std.objectHas(mixin._config, 'showMultiCluster') then mixin._config.showMultiCluster else false,
  grafanaDatasourceUid: if std.objectHas(mixin._config, 'grafanaDatasourceUid') then mixin._config.grafanaDatasourceUid else 'P09C4D52DEC9B98E6',
  grafanaIntervalMs: if std.objectHas(mixin._config, 'grafanaIntervalMs') then mixin._config.grafanaIntervalMs else 60000,
  grafanaNoDataState: 'OK',
  grafanaExecErrState: 'Error',
};

// Function to convert a Prometheus recording rule to Grafana recording rule format
local convertRecordingRule(rule, config) = {
  // In Grafana recording rules:
  // - name corresponds to the metric name (record)
  // - expr is the PromQL expression
  name: rule.record,
  query: {
    datasourceUid: config.grafanaDatasourceUid,
    expr: rule.expr,
    intervalMs: config.grafanaIntervalMs,
    maxDataPoints: 43200,
  },
  // If the rule has labels, include them
  [if std.objectHas(rule, 'labels') && std.length(std.objectFields(rule.labels)) > 0 then 'labels']: rule.labels,
};

// Create Grafana recording rules by processing each group in the Prometheus rules
local grafanaRules = [
  {
    name: group.name,
    interval: if std.objectHas(group, 'interval') then group.interval else '1m',
    rules: [
      convertRecordingRule(rule, config)
      for rule in group.rules
      if std.objectHas(rule, 'record')  // Only include recording rules
    ],
  }
  for group in mixin.prometheusRules.groups
  if std.length([rule for rule in group.rules if std.objectHas(rule, 'record')]) > 0  // Only include groups that have recording rules
];

// Output the final array as a JSON string
std.manifestJson(grafanaRules) 