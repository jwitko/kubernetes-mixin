local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local prometheus = g.query.prometheus;
local stat = g.panel.stat;
local table = g.panel.table;
local timeSeries = g.panel.timeSeries;
local var = g.dashboard.variable;

{
  local statPanel(title, unit, query) =
    stat.new(title)
    + stat.options.withColorMode('none')
    + stat.standardOptions.withUnit(unit)
    + stat.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval)
    + stat.queryOptions.withTargets([
      prometheus.new('${datasource}', query)
      + prometheus.withInstant(true),
    ]),

  local tsPanel =
    timeSeries {
      new(title):
        timeSeries.new(title)
        + timeSeries.options.legend.withShowLegend()
        + timeSeries.options.legend.withAsTable()
        + timeSeries.options.legend.withDisplayMode('table')
        + timeSeries.options.legend.withPlacement('right')
        + timeSeries.options.legend.withCalcs(['lastNotNull'])
        + timeSeries.options.tooltip.withMode('single')
        + timeSeries.fieldConfig.defaults.custom.withShowPoints('never')
        + timeSeries.fieldConfig.defaults.custom.withFillOpacity(10)
        + timeSeries.fieldConfig.defaults.custom.withSpanNulls(true)
        + timeSeries.queryOptions.withInterval($._config.grafanaK8s.minimumTimeInterval),
    },

  local variables = {
    datasource:
      var.datasource.new('datasource', 'prometheus')
      + var.datasource.withRegex($._config.datasourceFilterRegex)
      + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
      + var.datasource.generalOptions.withLabel('Data source')
      + {
        current: {
          selected: true,
          text: $._config.datasourceName,
          value: $._config.datasourceName,
        },
      },

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        $._config.clusterLabel,
        'up{%(windowsExporterSelector)s}' % $._config,
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.refresh.onTime()
      + (
        if $._config.showMultiCluster
        then var.query.generalOptions.showOnDashboard.withLabelAndValue()
        else var.query.generalOptions.showOnDashboard.withNothing()
      )
      + var.query.withSort(type='alphabetical'),

    instance:
      var.query.new('instance')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'instance',
        'windows_system_system_up_time{%(clusterLabel)s="$cluster"}' % $._config
      )
      + var.query.generalOptions.withLabel('instance')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue(),

    namespace:
      var.query.new('namespace')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'namespace',
        '(windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster"}' % $._config,
      )
      + var.query.generalOptions.withLabel('namespace')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),

    pod:
      var.query.new('pod')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'pod',
        '(windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster",namespace="$namespace"}' % $._config,
      )
      + var.query.generalOptions.withLabel('pod')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),
  },

  local links = {
    namespace: {
      title: 'Drill down to pods',
      url: '%(prefix)s/d/%(uid)s/k8s-resources-windows-namespace?${datasource:queryparam}&var-cluster=$cluster&var-namespace=${__data.fields.Namespace}' % {
        uid: $._config.grafanaDashboardIDs['k8s-resources-windows-namespace.json'],
        prefix: $._config.grafanaK8s.linkPrefix,
      },
    },

    pod: {
      title: 'Drill down to pods',
      url: '%(prefix)s/d/%(uid)s/k8s-resources-windows-pod?${datasource:queryparam}&var-cluster=$cluster&var-namespace=$namespace&var-pod=${__data.fields.Pod}' % {
        uid: $._config.grafanaDashboardIDs['k8s-resources-windows-pod.json'],
        prefix: $._config.grafanaK8s.linkPrefix,
      },
    },
  },

  grafanaDashboards+:: {
    'k8s-resources-windows-cluster.json':
      local panels = [
        statPanel(
          'CPU Utilisation',
          'none',
          '1 - avg(rate(windows_cpu_time_total{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, mode="idle"}[%(grafanaIntervalVar)s]))' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Requests Commitment',
          'percentunit',
          'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) / sum((count by (%(clusterLabel)s, instance) (sum by (%(clusterLabel)s, instance, core) ( windows_cpu_time_total{%(windowsExporterSelector)s} ))){%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Limits Commitment',
          'percentunit',
          'sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) / sum((count by (%(clusterLabel)s, instance) (sum by (%(clusterLabel)s, instance, core) ( windows_cpu_time_total{%(windowsExporterSelector)s} ))){%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Utilisation',
          'percentunit',
          '1 - sum((sum by (%(clusterLabel)s) (windows_memory_available_bytes{%(windowsExporterSelector)s} + windows_memory_cache_bytes{%(windowsExporterSelector)s})){%(clusterLabel)s="$cluster"}) / sum((sum by (%(clusterLabel)s) (windows_os_visible_memory_bytes{%(windowsExporterSelector)s})){%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Requests Commitment',
          'percentunit',
          'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) / sum((sum by (%(clusterLabel)s) (windows_os_visible_memory_bytes{%(windowsExporterSelector)s})){%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Limits Commitment',
          'percentunit',
          'sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) / sum((sum by (%(clusterLabel)s) (windows_os_visible_memory_bytes{%(windowsExporterSelector)s})){%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster"}) by (namespace) / sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster"}) by (namespace) / sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              namespace: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Requests',
              'Value #C': 'CPU Requests %',
              'Value #D': 'CPU Limits',
              'Value #E': 'CPU Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Memory Usage (Private Working Set)')
        + tsPanel.standardOptions.withUnit('decbytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Requests by Namespace')
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster"}) by (namespace) / sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster"}) by (namespace) / sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'namespace',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              namespace: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Usage',
            },
            properties: [
              {
                id: 'unit',
                value: 'decbytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Requests',
            },
            properties: [
              {
                id: 'unit',
                value: 'decbytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Memory Limits',
            },
            properties: [
              {
                id: 'unit',
                value: 'decbytes',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Cluster(Windows)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-windows-cluster.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=7)),

    'k8s-resources-windows-namespace.json':
      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod) / sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod) / sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'pod',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              pod: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              pod: 'Pod',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Requests',
              'Value #C': 'CPU Requests %',
              'Value #D': 'CPU Limits',
              'Value #E': 'CPU Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Pod',
            },
            properties: [
              {
                id: 'links',
                value: [links.pod],
              },
            ],
          },
        ]),

        tsPanel.new('Memory Usage (Private Working Set)')
        + tsPanel.standardOptions.withUnit('decbytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Quota')
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod) / sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod) / sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace"}) by (pod)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'pod',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              pod: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              pod: 'Pod',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Pod',
            },
            properties: [
              {
                id: 'links',
                value: [links.pod],
              },
            ],
          },
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Namespace(Windows)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-windows-namespace.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=7)),

    'k8s-resources-windows-pod.json':
      local panels = [
        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate((windows_container_cpu_usage_seconds_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){}[5m]) )){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum((kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              container: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'CPU Usage',
              'Value #B': 'CPU Requests',
              'Value #C': 'CPU Requests %',
              'Value #D': 'CPU Limits',
              'Value #E': 'CPU Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
          {
            matcher: {
              id: 'byName',
              options: 'Namespace',
            },
            properties: [
              {
                id: 'links',
                value: [links.namespace],
              },
            ],
          },
        ]),

        tsPanel.new('Memory Usage')
        + tsPanel.standardOptions.withUnit('decbytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Quota')
        + table.standardOptions.withUnit('bytes')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum((max by (%(clusterLabel)s, namespace, pod, container) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((((windows_container_memory_usage_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_commit_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s))_private_working_set_bytes{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container) / sum((kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} * on(container,pod,namespace,%(clusterLabel)s) ((windows_container_available{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)))){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}) by (container)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),
        ])

        + table.queryOptions.withTransformations([
          table.queryOptions.transformation.withId('joinByField')
          + table.queryOptions.transformation.withOptions({
            byField: 'container',
            mode: 'outer',
          }),

          table.queryOptions.transformation.withId('organize')
          + table.queryOptions.transformation.withOptions({
            excludeByName: {
              Time: true,
              'Time 1': true,
              'Time 2': true,
              'Time 3': true,
              'Time 4': true,
              'Time 5': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              container: 5,
              'Value #A': 6,
              'Value #B': 7,
              'Value #C': 8,
              'Value #D': 9,
              'Value #E': 10,
            },
            renameByName: {
              container: 'Container',
              'Value #A': 'Memory Usage',
              'Value #B': 'Memory Requests',
              'Value #C': 'Memory Requests %',
              'Value #D': 'Memory Limits',
              'Value #E': 'Memory Limits %',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/%/',
            },
            properties: [
              {
                id: 'unit',
                value: 'percentunit',
              },
            ],
          },
        ]),

        tsPanel.new('Network I/O')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sort_desc(sum by (container) (rate((windows_container_network_receive_bytes_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s])))' % $._config
          )
          + prometheus.withLegendFormat('Received : {{ container }}'),

          prometheus.new(
            '${datasource}',
            'sort_desc(sum by (container) (rate((windows_container_network_transmit_bytes_total{%(windowsExporterSelector)s, container_id != ""} * on(container_id, %(clusterLabel)s) group_left(container, pod, namespace) max(kube_pod_container_info{%(kubeStateMetricsSelector)s, container_id != ""}) by(container, container_id, pod, namespace, %(clusterLabel)s)){%(clusterLabel)s="$cluster", namespace="$namespace", pod="$pod"}[%(grafanaIntervalVar)s])))' % $._config
          )
          + prometheus.withLegendFormat('Transmitted : {{ container }}'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Pod(Windows)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-windows-pod.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.namespace, variables.pod])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=7)),

    'k8s-windows-cluster-rsrc-use.json':
      local panels = [
        tsPanel.new('CPU Utilisation')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(1 - avg by (%(clusterLabel)s, instance) ( rate(windows_cpu_time_total{%(windowsExporterSelector)s,mode="idle"}[1m]) )){%(clusterLabel)s="$cluster"} * (count by (%(clusterLabel)s, instance) (sum by (%(clusterLabel)s, instance, core) ( windows_cpu_time_total{%(windowsExporterSelector)s} ))){%(clusterLabel)s="$cluster"} / scalar(sum((count by (%(clusterLabel)s, instance) (sum by (%(clusterLabel)s, instance, core) ( windows_cpu_time_total{%(windowsExporterSelector)s} ))){%(clusterLabel)s="$cluster"}))' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Memory Utilisation')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(((sum by (%(clusterLabel)s, instance) ( windows_os_visible_memory_bytes{%(windowsExporterSelector)s} )) - (sum by (%(clusterLabel)s, instance) ( (windows_memory_available_bytes{%(windowsExporterSelector)s}) ))) / scalar(sum((sum by (%(clusterLabel)s, instance) ( windows_os_visible_memory_bytes{%(windowsExporterSelector)s} ))))){%(clusterLabel)s="$cluster"}' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Memory Saturation (Swap I/O Pages)')
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(irate(windows_memory_swap_page_operations_total{%(windowsExporterSelector)s}[5m])){%(clusterLabel)s="$cluster"}' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Disk IO Utilisation')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(avg by (%(clusterLabel)s, instance) ( (irate(windows_logical_disk_read_seconds_total{%(windowsExporterSelector)s}[1m]) + irate(windows_logical_disk_write_seconds_total{%(windowsExporterSelector)s}[1m])) )){%(clusterLabel)s="$cluster"} / scalar((count by (%(clusterLabel)s) ( windows_system_system_up_time{%(windowsExporterSelector)s} )){%(clusterLabel)s="$cluster"})' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Net Utilisation (Transmitted)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(sum by (%(clusterLabel)s, instance) ( (irate(windows_net_bytes_total{%(windowsExporterSelector)s}[1m])) )){%(clusterLabel)s="$cluster"}' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Net Utilisation (Dropped)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(sum by (%(clusterLabel)s, instance) ( (irate(windows_net_packets_received_discarded_total{%(windowsExporterSelector)s}[1m]) + irate(windows_net_packets_outbound_discarded_total{%(windowsExporterSelector)s}[1m])) )){%(clusterLabel)s="$cluster"}' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),

        tsPanel.new('Disk Capacity')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by (instance)((max by (%(clusterLabel)s,instance,volume)( (windows_logical_disk_size_bytes{%(windowsExporterSelector)s} - windows_logical_disk_free_bytes{%(windowsExporterSelector)s}) / windows_logical_disk_size_bytes{%(windowsExporterSelector)s} )){%(clusterLabel)s="$cluster"})' % $._config
          )
          + prometheus.withLegendFormat('{{instance}}'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sUSE Method / Cluster(Windows)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-windows-cluster-rsrc-use.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),

    'k8s-windows-node-rsrc-use.json':
      local panels = [
        tsPanel.new('CPU Utilisation')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(1 - avg by (%(clusterLabel)s, instance) ( rate(windows_cpu_time_total{%(windowsExporterSelector)s,mode="idle"}[1m]) )){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('Utilisation'),
        ]),

        tsPanel.new('CPU Usage Per Core')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by (core) (irate(windows_cpu_time_total{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, mode!="idle", instance="$instance"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('{{core}}'),
        ]),

        tsPanel.new('Memory Utilisation %')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(1 - ((sum by (%(clusterLabel)s, instance) ( (windows_memory_available_bytes{%(windowsExporterSelector)s}) )) / (sum by (%(clusterLabel)s, instance) ( windows_os_visible_memory_bytes{%(windowsExporterSelector)s} )))){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('Memory'),
        ]),

        tsPanel.new('Memory Usage')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            |||
              max(
                windows_os_visible_memory_bytes{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, instance="$instance"}
                - windows_memory_available_bytes{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, instance="$instance"}
              )
            ||| % $._config
          )
          + prometheus.withLegendFormat('memory used'),

          prometheus.new(
            '${datasource}',
            'max(((windows_memory_cache_bytes{%(windowsExporterSelector)s} + windows_memory_modified_page_list_bytes{%(windowsExporterSelector)s} + windows_memory_standby_cache_core_bytes{%(windowsExporterSelector)s} + windows_memory_standby_cache_normal_priority_bytes{%(windowsExporterSelector)s} + windows_memory_standby_cache_reserve_bytes{%(windowsExporterSelector)s})){%(clusterLabel)s="$cluster", instance="$instance"})' % $._config
          )
          + prometheus.withLegendFormat('memory cached'),

          prometheus.new(
            '${datasource}',
            'max(windows_memory_available_bytes{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, instance="$instance"})' % $._config
          )
          + prometheus.withLegendFormat('memory free'),
        ]),

        tsPanel.new('Memory Saturation (Swap I/O) Pages')
        + tsPanel.gridPos.withW(8)
        + tsPanel.standardOptions.withUnit('short')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(irate(windows_memory_swap_page_operations_total{%(windowsExporterSelector)s}[5m])){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('Swap IO'),
        ]),

        tsPanel.new('Disk IO Utilisation')
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(avg by (%(clusterLabel)s, instance) ( (irate(windows_logical_disk_read_seconds_total{%(windowsExporterSelector)s}[1m]) + irate(windows_logical_disk_write_seconds_total{%(windowsExporterSelector)s}[1m])) )){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('Utilisation'),
        ]),

        tsPanel.new('Disk IO')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'max(rate(windows_logical_disk_read_bytes_total{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, instance="$instance"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('read'),

          prometheus.new(
            '${datasource}',
            'max(rate(windows_logical_disk_write_bytes_total{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, instance="$instance"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('written'),

          prometheus.new(
            '${datasource}',
            'max(rate(windows_logical_disk_read_seconds_total{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s,  instance="$instance"}[%(grafanaIntervalVar)s]) + rate(windows_logical_disk_write_seconds_total{%(clusterLabel)s="$cluster", %(windowsExporterSelector)s, instance="$instance"}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('io time'),
        ])
        + tsPanel.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/io time/',
            },
            properties: [
              {
                id: 'unit',
                value: 'ms',
              },
            ],
          },
        ]),

        tsPanel.new('Disk Utilisation')
        + tsPanel.gridPos.withW(24)
        + tsPanel.standardOptions.withUnit('percentunit')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(max by (%(clusterLabel)s,instance,volume)( (windows_logical_disk_size_bytes{%(windowsExporterSelector)s} - windows_logical_disk_free_bytes{%(windowsExporterSelector)s}) / windows_logical_disk_size_bytes{%(windowsExporterSelector)s} )){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('{{volume}}'),
        ]),

        tsPanel.new('Net Utilisation (Transmitted)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(sum by (%(clusterLabel)s, instance) ( (irate(windows_net_bytes_total{%(windowsExporterSelector)s}[1m])) )){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('Utilisation'),
        ]),

        tsPanel.new('Net Saturation (Dropped)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            '(sum by (%(clusterLabel)s, instance) ( (irate(windows_net_packets_received_discarded_total{%(windowsExporterSelector)s}[1m]) + irate(windows_net_packets_outbound_discarded_total{%(windowsExporterSelector)s}[1m])) )){%(clusterLabel)s="$cluster", instance="$instance"}' % $._config
          )
          + prometheus.withLegendFormat('Saturation'),
        ]),
      ];

      g.dashboard.new('%(dashboardNamePrefix)sUSE Method / Node(Windows)' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-windows-node-rsrc-use.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster, variables.instance])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=12, panelHeight=7)),
  },
}
