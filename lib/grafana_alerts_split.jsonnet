// Import the main mixin which aggregates everything
local mixin = import '../mixin.libsonnet';
// Import utils for helper functions if needed
local utils = import '../lib/utils.libsonnet';

// Make sure showMultiCluster exists in the configuration
local config = mixin._config {
  showMultiCluster: if std.objectHas(mixin._config, 'showMultiCluster') then mixin._config.showMultiCluster else false,
  grafanaDatasourceUid: if std.objectHas(mixin._config, 'grafanaDatasourceUid') then mixin._config.grafanaDatasourceUid else 'P09C4D52DEC9B98E6',
  grafanaIntervalMs: if std.objectHas(mixin._config, 'grafanaIntervalMs') then mixin._config.grafanaIntervalMs else 60000,
  grafanaNoDataState: 'OK',
  grafanaExecErrState: 'Error',
};

// Function to remove newlines and extra whitespace from expressions
local cleanExpr(expr) =
  std.strReplace(std.strReplace(expr, '\n', ' '), '  ', ' ');

// Access the aggregated Grafana alerts (object keyed by group name)
local aggregatedGrafanaAlerts = mixin.grafanaAlerts;

// Process alerts to remove newlines from expressions
local cleanedAlerts = {
  [groupName]: [
    alert {
      [if std.objectHas(alert, 'grafana_alert') then 'grafana_alert']: alert.grafana_alert {
        [if std.objectHas(alert.grafana_alert, 'data') then 'data']: [
          item {
            [if std.objectHas(item, 'model') && std.objectHas(item.model, 'expr') then 'model']:
              item.model {
                expr: cleanExpr(item.model.expr),
              },
          }
          for item in alert.grafana_alert.data
        ],
      },
    }
    for alert in aggregatedGrafanaAlerts[groupName]
  ]
  for groupName in std.objectFields(aggregatedGrafanaAlerts)
};

// Function to clean group name for file name
local cleanGroupName(name) =
  std.strReplace(std.strReplace(std.strReplace(name, ' ', '_'), ':', '_'), '-', '_');

// Function to remove all newlines and unnecessary whitespace from JSON
local compactJSON(json) =
  std.strReplace(std.strReplace(std.strReplace(json, '\n', ''), '  ', ''), ': ', ':');

// Create a separate file for each alert group
{
  // For each group name, create a file with sanitized name
  [cleanGroupName(groupName) + '.json']: compactJSON(std.manifestJson({
    name: groupName,
    // Use a default interval or potentially make it configurable via _config
    interval: std.get(config, 'grafanaAlertGroupInterval', '1m'),
    rules: cleanedAlerts[groupName],  // The array of rules for this group with cleaned expressions
  }))  // Compact the JSON output
  // Iterate over the group names (keys) in the aggregated object
  for groupName in std.objectFields(aggregatedGrafanaAlerts)
}
