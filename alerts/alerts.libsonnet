// Import individual alert definition files
local links = import '../lib/add-runbook-links.libsonnet';
local apps = import 'apps_alerts.libsonnet';
local apiserver = import 'kube_apiserver.libsonnet';
local controllerManager = import 'kube_controller_manager.libsonnet';
local proxy = import 'kube_proxy.libsonnet';
local scheduler = import 'kube_scheduler.libsonnet';
local kubelet = import 'kubelet.libsonnet';
local resource = import 'resource_alerts.libsonnet';
local storage = import 'storage_alerts.libsonnet';
local system = import 'system_alerts.libsonnet';

// Main object combining Prometheus alerts and Grafana alerts
(apps + resource + storage + system + apiserver + kubelet + scheduler + controllerManager + proxy + links)
{
  // Explicitly merge Grafana alert contributions
  grafanaAlerts: std.foldl(
    function(obj1, obj2) std.mergePatch(obj1, obj2),
    [
      // Use std.get to safely access contributions in case a file doesn't define it
      std.get(apps, '_grafanaAlertsContribution', {}),
      std.get(resource, '_grafanaAlertsContribution', {}),
      std.get(storage, '_grafanaAlertsContribution', {}),
      std.get(system, '_grafanaAlertsContribution', {}),
      std.get(apiserver, '_grafanaAlertsContribution', {}),
      std.get(kubelet, '_grafanaAlertsContribution', {}),
      std.get(scheduler, '_grafanaAlertsContribution', {}),
      std.get(controllerManager, '_grafanaAlertsContribution', {}),
      std.get(proxy, '_grafanaAlertsContribution', {}),
      // links likely doesn't have it, but added for safety
      std.get(links, '_grafanaAlertsContribution', {}),
    ],
    {}
  ),
}
