// Import the main mixin which aggregates everything
local mixin = import '../mixin.libsonnet';
// Import utils for helper functions if needed (e.g., accessing config)
local utils = import '../lib/utils.libsonnet';

// Make sure showMultiCluster exists in the configuration
local config = mixin._config {
  showMultiCluster: if std.objectHas(mixin._config, 'showMultiCluster') then mixin._config.showMultiCluster else false,
  grafanaDatasourceUid: if std.objectHas(mixin._config, 'grafanaDatasourceUid') then mixin._config.grafanaDatasourceUid else 'P09C4D52DEC9B98E6',
  grafanaIntervalMs: if std.objectHas(mixin._config, 'grafanaIntervalMs') then mixin._config.grafanaIntervalMs else 60000,
  grafanaNoDataState: 'OK',
  grafanaExecErrState: 'Error',
};

// Access the aggregated Grafana alerts (object keyed by group name)
local aggregatedGrafanaAlerts = mixin.grafanaAlerts;

// Transform the aggregated object into an array of Grafana groups
local finalGrafanaGroups = [
  {
    name: groupName,
    // Use a default interval or potentially make it configurable via _config
    interval: std.get(config, 'grafanaAlertGroupInterval', '1m'),  // Example: get from config or default
    rules: aggregatedGrafanaAlerts[groupName],  // The array of rules for this group
  }
  // Iterate over the group names (keys) in the aggregated object
  for groupName in std.objectFields(aggregatedGrafanaAlerts)
];

// Output the final array as a JSON string
// Note: The example new-alerts.txt shows multiple groups concatenated.
// If Grafana needs one JSON object per group file, this needs adjustment.
// If Grafana needs one large file with all groups in one array, this is closer.
// Assuming Grafana wants a list of groups for now.
std.manifestJson(finalGrafanaGroups)
