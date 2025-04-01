local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    // Ensure required fields have default values
    showMultiCluster: false,
    clusterLabel: 'cluster',
    namespaceLabel: 'namespace',
    
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    namespaceSelector: null,
    prefixedNamespaceSelector: if self.namespaceSelector != null then self.namespaceSelector + ',' else '',
    kubeletSelector: 'job="kubelet"',
    cadvisorSelector: 'job="cadvisor"',
    nodeSelector: 'job="node-exporter"',
    fsSpaceFillingUpCriticalThreshold: 15,
    fsSpaceFillingUpWarningThreshold: 40,
    cpuThrottlingPercent: 25,
    cpuThrottlingSelector: '',
    // Set this selector for seleting namespaces that contains resources used for overprovision
    // See https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#how-can-i-configure-overprovisioning-with-cluster-autoscaler
    // for more details.
    ignoringOverprovisionedWorkloadSelector: '',
    namespaceOvercommitFactor: 1.5,
    kubeCpuOvercommitSelector: '',

    // --- Grafana Alert Configuration ---
    grafanaDatasourceUid: 'P09C4D52DEC9B98E6', // Default Prometheus Datasource UID in Grafana
    grafanaIntervalMs: 60000, // Default evaluation interval
    grafanaNoDataState: 'OK',
    grafanaExecErrState: 'Error',
    // -----------------------------------
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-resources',
        rules: [
          {
            alert: 'KubeCPUOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted CPU resource requests.',
            },
            "for": '10m',
            // Prometheus-specific part
            expr: if $._config.showMultiCluster then |||
              sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s}) by (%(clusterLabel)s) - (sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu"}) by (%(clusterLabel)s) - max(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu"}) by (%(clusterLabel)s)) > 0
              and
              (sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu"}) by (%(clusterLabel)s) - max(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu"}) by (%(clusterLabel)s)) > 0
            ||| % $._config else |||
              sum(namespace_cpu:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s}) - (sum(kube_node_status_allocatable{resource="cpu", %(kubeStateMetricsSelector)s}) - max(kube_node_status_allocatable{resource="cpu", %(kubeStateMetricsSelector)s})) > 0
              and
              (sum(kube_node_status_allocatable{resource="cpu", %(kubeStateMetricsSelector)s}) - max(kube_node_status_allocatable{resource="cpu", %(kubeStateMetricsSelector)s})) > 0
            ||| % $._config,
            // Add annotations based on config
            [if $._config.showMultiCluster then 'description']: 'Cluster {{ $labels.%(clusterLabel)s }} has overcommitted CPU resource requests for Pods by {{ $value }} CPU shares and cannot tolerate node failure.' % $._config,
            [if !$._config.showMultiCluster then 'description']: 'Cluster has overcommitted CPU resource requests for Pods by {{ $value }} CPU shares and cannot tolerate node failure.',
          },
          {
            alert: 'KubeMemoryOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted memory resource requests.',
            },
            "for": '10m',
          } +
          if $._config.showMultiCluster then {
            expr: |||
              sum(namespace_memory:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s}) by (%(clusterLabel)s) - (sum(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) by (%(clusterLabel)s) - max(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) by (%(clusterLabel)s)) > 0
              and
              (sum(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) by (%(clusterLabel)s) - max(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) by (%(clusterLabel)s)) > 0
            ||| % $._config,
            annotations+: {
              description: 'Cluster {{ $labels.%(clusterLabel)s }} has overcommitted memory resource requests for Pods by {{ $value | humanize }} bytes and cannot tolerate node failure.' % $._config,
            },
          } else
            {
              expr: |||
                sum(namespace_memory:kube_pod_container_resource_requests:sum{%(ignoringOverprovisionedWorkloadSelector)s}) - (sum(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) - max(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s})) > 0
                and
                (sum(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) - max(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s})) > 0
              ||| % $._config,
              annotations+: {
                description: 'Cluster has overcommitted memory resource requests for Pods by {{ $value | humanize }} bytes and cannot tolerate node failure.',
              },
            },
          {
            alert: 'KubeCPUQuotaOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted CPU resource requests.',
            },
            "for": '5m',
          } +
          if $._config.showMultiCluster then {
            expr: |||
              sum(min without(resource) (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource=~"(cpu|requests.cpu)"})) by (%(clusterLabel)s)
                /
              sum(kube_node_status_allocatable{resource="cpu", %(kubeStateMetricsSelector)s}) by (%(clusterLabel)s)
                > %(namespaceOvercommitFactor)s
            ||| % $._config,
            annotations+: {
              description: 'Cluster {{ $labels.%(clusterLabel)s }}  has overcommitted CPU resource requests for Namespaces.' % $._config,
            },
          } else
            {
              expr: |||
                sum(min without(resource) (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource=~"(cpu|requests.cpu)"}))
                  /
                sum(kube_node_status_allocatable{resource="cpu", %(kubeStateMetricsSelector)s})
                  > %(namespaceOvercommitFactor)s
              ||| % $._config,
              annotations+: {
                description: 'Cluster has overcommitted CPU resource requests for Namespaces.',
              },
            },
          {
            alert: 'KubeMemoryQuotaOvercommit',
            labels: {
              severity: 'warning',
            },
            annotations: {
              summary: 'Cluster has overcommitted memory resource requests.',
            },
            "for": '5m',
          } +
          if $._config.showMultiCluster then {
            expr: |||
              sum(min without(resource) (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource=~"(memory|requests.memory)"})) by (%(clusterLabel)s)
                /
              sum(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s}) by (%(clusterLabel)s)
                > %(namespaceOvercommitFactor)s
            ||| % $._config,
            annotations+: {
              description: 'Cluster {{ $labels.%(clusterLabel)s }}  has overcommitted memory resource requests for Namespaces.' % $._config,
            },
          } else
            {
              expr: |||
                sum(min without(resource) (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard", resource=~"(memory|requests.memory)"}))
                  /
                sum(kube_node_status_allocatable{resource="memory", %(kubeStateMetricsSelector)s})
                  > %(namespaceOvercommitFactor)s
              ||| % $._config,
              annotations+: {
                description: 'Cluster has overcommitted memory resource requests for Namespaces.',
              },
            },
          {
            alert: 'KubeQuotaAlmostFull',
            expr: |||
              kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                / ignoring(instance, job, type)
              (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"} > 0)
                > 0.9 < 1
            ||| % $._config,
            "for": '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Namespace quota is going to be full.',
            },
          },
          {
            alert: 'KubeQuotaFullyUsed',
            expr: |||
              kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                / ignoring(instance, job, type)
              (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"} > 0)
                == 1
            ||| % $._config,
            "for": '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Namespace quota is fully used.',
            },
          },
          {
            alert: 'KubeQuotaExceeded',
            expr: |||
              kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="used"}
                / ignoring(instance, job, type)
              (kube_resourcequota{%(prefixedNamespaceSelector)s%(kubeStateMetricsSelector)s, type="hard"} > 0)
                > 1
            ||| % $._config,
            "for": '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Namespace {{ $labels.namespace }} is using {{ $value | humanizePercentage }} of its {{ $labels.resource }} quota%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Namespace quota has exceeded the limits.',
            },
          },
          {
            alert: 'CPUThrottlingHigh',
            expr: |||
              sum(increase(container_cpu_cfs_throttled_periods_total{container!="", %(cadvisorSelector)s, %(cpuThrottlingSelector)s}[5m])) without (id, metrics_path, name, image, endpoint, job, node)
                / on (%(clusterLabel)s, %(namespaceLabel)s, pod, container, instance) group_left
              sum(increase(container_cpu_cfs_periods_total{%(cadvisorSelector)s, %(cpuThrottlingSelector)s}[5m])) without (id, metrics_path, name, image, endpoint, job, node)
                > ( %(cpuThrottlingPercent)s / 100 )
            ||| % $._config,
            "for": '15m',
            labels: {
              severity: 'info',
            },
            annotations: {
              description: '{{ $value | humanizePercentage }} throttling of CPU in namespace {{ $labels.namespace }} for container {{ $labels.container }} in pod {{ $labels.pod }}%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Processes experience elevated CPU throttling.',
            },
          },
        ],
      },
    ],
  },

  // New top-level field for Grafana alerts
  _grafanaAlertsContribution:: {
    [group.name]: [
      // Transform each alert rule directly
      utils.makeGrafanaAlertBoilerplate({
        alert: rule.alert,
        expr: rule.expr,
        'for': std.get(rule, 'for', '5m'),
        labels: { [k]: rule.labels[k] for k in std.objectFields(std.get(rule, 'labels', {})) },
        annotations: { [k]: rule.annotations[k] for k in std.objectFields(std.get(rule, 'annotations', {})) },
      }, $._config)
      for rule in group.rules // Iterate over the rules
      if std.objectHas(rule, 'alert')
    ]
    for group in self.prometheusAlerts.groups // Iterate over self
  },
}
