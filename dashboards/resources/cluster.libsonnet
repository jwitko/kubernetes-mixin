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

  grafanaDashboards+:: {
    'k8s-resources-cluster.json':
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
            'up{%(cadvisorSelector)s}' % $._config,
          )
          + var.query.generalOptions.withLabel('cluster')
          + var.query.refresh.onTime()
          + (
            if $._config.showMultiCluster
            then var.query.generalOptions.showOnDashboard.withLabelAndValue()
            else var.query.generalOptions.showOnDashboard.withNothing()
          )
          + var.query.withSort(type='alphabetical'),
      };

      local links = {
        namespace: {
          title: 'Drill down to pods',
          url: '%(prefix)s/d/%(uid)s/k8s-resources-namespace?${datasource:queryparam}&var-cluster=$cluster&var-namespace=${__data.fields.Namespace}' % {
            uid: $._config.grafanaDashboardIDs['k8s-resources-namespace.json'],
            prefix: $._config.grafanaK8s.linkPrefix,
          },
        },
      };

      local panels = [
        statPanel(
          'CPU Utilisation',
          'percentunit',
          '(avg by (%(clusterLabel)s) ( (avg by (%(clusterLabel)s, node) ( sum without (mode) ( rate(node_cpu_seconds_total{mode!="idle",mode!="iowait",mode!="steal",%(nodeExporterSelector)s}[5m]) ) )) )){%(clusterLabel)s="$cluster"}' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Requests Commitment',
          'percentunit',
          'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'CPU Limits Commitment',
          'percentunit',
          'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="cpu",%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Utilisation',
          'percentunit',
          '1 - sum((sum( node_memory_MemAvailable_bytes{%(nodeExporterSelector)s} or ( node_memory_Buffers_bytes{%(nodeExporterSelector)s} + node_memory_Cached_bytes{%(nodeExporterSelector)s} + node_memory_MemFree_bytes{%(nodeExporterSelector)s} + node_memory_Slab_bytes{%(nodeExporterSelector)s} ) ) by (%(clusterLabel)s)){%(clusterLabel)s="$cluster"}) / sum(node_memory_MemTotal_bytes{%(nodeExporterSelector)s,%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Requests Commitment',
          'percentunit',
          'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        statPanel(
          'Memory Limits Commitment',
          'percentunit',
          'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) / sum(kube_node_status_allocatable{%(kubeStateMetricsSelector)s,resource="memory",%(clusterLabel)s="$cluster"})' % $._config
        )
        + stat.gridPos.withW(4)
        + stat.gridPos.withH(3),

        tsPanel.new('CPU Usage')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m]) ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) ( 1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""}) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('CPU Quota')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(kube_pod_owner{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'count(avg((max by (%(clusterLabel)s, namespace, workload, pod) ( label_replace( kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}, "workload", "$1", "owner_name", "(.*)" ) )){%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m]) ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) ( 1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""}) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m]) ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) ( 1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""}) )){%(clusterLabel)s="$cluster"}) by (namespace) / sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_requests{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (%(clusterLabel)s, namespace, pod, container) ( rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, image!=""}[5m]) ) * on (%(clusterLabel)s, namespace, pod) group_left(node) topk by (%(clusterLabel)s, namespace, pod) ( 1, max by(%(clusterLabel)s, namespace, pod, node) (kube_pod_info{node!=""}) )){%(clusterLabel)s="$cluster"}) by (namespace) / sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_limits{resource="cpu",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
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
              'Time 6': true,
              'Time 7': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              namespace: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Pods',
              'Value #B': 'Workloads',
              'Value #C': 'CPU Usage',
              'Value #D': 'CPU Requests',
              'Value #E': 'CPU Requests %',
              'Value #F': 'CPU Limits',
              'Value #G': 'CPU Limits %',
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

        tsPanel.new('Memory')
        + tsPanel.standardOptions.withUnit('bytes')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Memory Requests by Namespace')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(kube_pod_owner{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'count(avg((max by (%(clusterLabel)s, namespace, workload, pod) ( label_replace( kube_pod_owner{%(kubeStateMetricsSelector)s, owner_kind="Job"}, "workload", "$1", "owner_name", "(.*)" ) )){%(clusterLabel)s="$cluster"}) by (workload, namespace)) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace) / sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_requests{resource="memory",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(container_memory_rss{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", container!=""}) by (namespace) / sum((sum by (namespace, %(clusterLabel)s) ( sum by (namespace, pod, %(clusterLabel)s) ( max by (namespace, pod, container, %(clusterLabel)s) ( kube_pod_container_resource_limits{resource="memory",%(kubeStateMetricsSelector)s} ) * on(namespace, pod, %(clusterLabel)s) group_left() max by (namespace, pod, %(clusterLabel)s) ( kube_pod_status_phase{phase=~"Pending|Running"} == 1 ) ) )){%(clusterLabel)s="$cluster"}) by (namespace)' % $._config)
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
              'Time 6': true,
              'Time 7': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              'Time 7': 6,
              namespace: 7,
              'Value #A': 8,
              'Value #B': 9,
              'Value #C': 10,
              'Value #D': 11,
              'Value #E': 12,
              'Value #F': 13,
              'Value #G': 14,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Pods',
              'Value #B': 'Workloads',
              'Value #C': 'Memory Usage',
              'Value #D': 'Memory Requests',
              'Value #E': 'Memory Requests %',
              'Value #F': 'Memory Limits',
              'Value #G': 'Memory Limits %',
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
                value: 'bytes',
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
                value: 'bytes',
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
                value: 'bytes',
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

        table.new('Current Network Usage')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(rate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(rate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(rate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum(rate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config)
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
              'Time 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              namespace: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'Current Receive Bandwidth',
              'Value #B': 'Current Transmit Bandwidth',
              'Value #C': 'Rate of Received Packets',
              'Value #D': 'Rate of Transmitted Packets',
              'Value #E': 'Rate of Received Packets Dropped',
              'Value #F': 'Rate of Transmitted Packets Dropped',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/Bandwidth/',
            },
            properties: [
              {
                id: 'unit',
                value: 'Bps',
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Packets/',
            },
            properties: [
              {
                id: 'unit',
                value: 'pps',
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

        tsPanel.new('Receive Bandwidth')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Transmit Bandwidth')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Namespace: Received')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'avg(irate(container_network_receive_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Average Container Bandwidth by Namespace: Transmitted')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'avg(irate(container_network_transmit_bytes_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(irate(container_network_receive_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(irate(container_network_transmit_packets_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Received Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(irate(container_network_receive_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('Rate of Transmitted Packets Dropped')
        + tsPanel.standardOptions.withUnit('pps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum(irate(container_network_transmit_packets_dropped_total{%(cadvisorSelector)s, %(clusterLabel)s="$cluster", %(namespaceLabel)s=~".+"}[%(grafanaIntervalVar)s])) by (namespace)' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('IOPS(Reads+Writes)')
        + tsPanel.standardOptions.withUnit('iops')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'ceil(sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s])))' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        tsPanel.new('ThroughPut(Read+Write)')
        + tsPanel.standardOptions.withUnit('Bps')
        + tsPanel.queryOptions.withTargets([
          prometheus.new(
            '${datasource}',
            'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(diskDeviceSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config
          )
          + prometheus.withLegendFormat('__auto'),
        ]),

        table.new('Current Storage IO')
        + table.queryOptions.withTargets([
          prometheus.new('${datasource}', 'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(namespace) (rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(namespace) (rate(container_fs_reads_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(namespace) (rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config)
          + prometheus.withInstant(true)
          + prometheus.withFormat('table'),

          prometheus.new('${datasource}', 'sum by(namespace) (rate(container_fs_reads_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]) + rate(container_fs_writes_bytes_total{%(cadvisorSelector)s, %(diskDeviceSelector)s, %(containerfsSelector)s, %(clusterLabel)s="$cluster", namespace!=""}[%(grafanaIntervalVar)s]))' % $._config)
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
              'Time 6': true,
            },
            indexByName: {
              'Time 1': 0,
              'Time 2': 1,
              'Time 3': 2,
              'Time 4': 3,
              'Time 5': 4,
              'Time 6': 5,
              namespace: 6,
              'Value #A': 7,
              'Value #B': 8,
              'Value #C': 9,
              'Value #D': 10,
              'Value #E': 11,
              'Value #F': 12,
            },
            renameByName: {
              namespace: 'Namespace',
              'Value #A': 'IOPS(Reads)',
              'Value #B': 'IOPS(Writes)',
              'Value #C': 'IOPS(Reads + Writes)',
              'Value #D': 'Throughput(Read)',
              'Value #E': 'Throughput(Write)',
              'Value #F': 'Throughput(Read + Write)',
            },
          }),
        ])

        + table.standardOptions.withOverrides([
          {
            matcher: {
              id: 'byRegexp',
              options: '/IOPS/',
            },
            properties: [
              {
                id: 'unit',
                value: 'iops',
              },
            ],
          },
          {
            matcher: {
              id: 'byRegexp',
              options: '/Throughput/',
            },
            properties: [
              {
                id: 'unit',
                value: 'Bps',
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

      g.dashboard.new('%(dashboardNamePrefix)sCompute Resources / Cluster' % $._config.grafanaK8s)
      + g.dashboard.withUid($._config.grafanaDashboardIDs['k8s-resources-cluster.json'])
      + g.dashboard.withTags($._config.grafanaK8s.dashboardTags)
      + g.dashboard.withEditable(false)
      + g.dashboard.time.withFrom('now-1h')
      + g.dashboard.time.withTo('now')
      + g.dashboard.withRefresh($._config.grafanaK8s.refresh)
      + g.dashboard.withVariables([variables.datasource, variables.cluster])
      + g.dashboard.withPanels(g.util.grid.wrapPanels(panels, panelWidth=24, panelHeight=6)),
  },
}
