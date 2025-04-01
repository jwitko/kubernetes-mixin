local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',

    clusterLabel: 'cluster',
    showMultiCluster: false,
    namespaceLabel: 'namespace',

    certExpirationWarningSeconds: 7 * 24 * 3600,
    certExpirationCriticalSeconds: 1 * 24 * 3600,

    SLOs: {
      apiserver: {
        days: 30,
        target: 0.99,
        windows: [
          { severity: 'critical', 'for': '2m', long: '1h', short: '5m', factor: 14.4 },
          { severity: 'critical', 'for': '15m', long: '6h', short: '30m', factor: 6 },
          { severity: 'warning', 'for': '1h', long: '1d', short: '2h', factor: 3 },
          { severity: 'warning', 'for': '3h', long: '3d', short: '6h', factor: 1 },
        ],
      },
    },

    // API Server config options
    kubeApiserverReadSelector: 'verb=~"LIST|GET"',
    kubeApiserverWriteSelector: 'verb=~"POST|PUT|PATCH|DELETE"',
    kubeApiserverNonStreamingSelector: 'subresource!="proxy",verb!~"CONNECT|WATCH"',
    kubeApiserverReadResourceLatency: '1',
    kubeApiserverReadNamespaceLatency: '5',
    kubeApiserverReadClusterLatency: '30',
    kubeApiserverWriteLatency: '1',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kube-apiserver-slos',
        rules: [
          {
            alert: 'KubeAPIErrorBudgetBurn',
            expr: |||
              sum by(%s) (
                (
                  (
                    # too slow
                    sum by (%s) (rate(apiserver_request_sli_duration_seconds_count{%s,%s,%s}[%s]))
                    -
                    (
                      (
                        sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s,%s,%s,scope=~"resource|",le=~"%s"}[%s]))
                        or
                        vector(0)
                      )
                      +
                      sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s,%s,%s,scope="namespace",le=~"%s"}[%s]))
                      +
                      sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s,%s,%s,scope="cluster",le=~"%s"}[%s]))
                    )
                  )
                  +
                  # errors
                  sum by (%s) (rate(apiserver_request_total{%s,%s,code=~"5.."}[%s]))
                )
                /
                sum by (%s) (rate(apiserver_request_total{%s,%s}[%s]))
              ) > (%.2f * %.5f)
              and
              on(%s)
              sum by(%s) (
                (
                  (
                    # too slow
                    sum by (%s) (rate(apiserver_request_sli_duration_seconds_count{%s,%s,%s}[%s]))
                    -
                    (
                      (
                        sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s,%s,%s,scope=~"resource|",le=~"%s"}[%s]))
                        or
                        vector(0)
                      )
                      +
                      sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s,%s,%s,scope="namespace",le=~"%s"}[%s]))
                      +
                      sum by (%s) (rate(apiserver_request_sli_duration_seconds_bucket{%s,%s,%s,scope="cluster",le=~"%s"}[%s]))
                    )
                  )
                  +
                  # errors
                  sum by (%s) (rate(apiserver_request_total{%s,%s,code=~"5.."}[%s]))
                )
                /
                sum by (%s) (rate(apiserver_request_total{%s,%s}[%s]))
              ) > (%.2f * %.5f)
            ||| % [
              $._config.clusterLabel,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              w.long,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              $._config.kubeApiserverReadResourceLatency,
              w.long,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              $._config.kubeApiserverReadNamespaceLatency,
              w.long,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              $._config.kubeApiserverReadClusterLatency,
              w.long,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              w.long,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              w.long,
              w.factor,
              (1 - $._config.SLOs.apiserver.target),
              $._config.clusterLabel,
              $._config.clusterLabel,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              w.short,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              $._config.kubeApiserverReadResourceLatency,
              w.short,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              $._config.kubeApiserverReadNamespaceLatency,
              w.short,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              $._config.kubeApiserverNonStreamingSelector,
              $._config.kubeApiserverReadClusterLatency,
              w.short,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              w.short,
              $._config.clusterLabel,
              $._config.kubeApiserverSelector,
              $._config.kubeApiserverReadSelector,
              w.short,
              w.factor,
              (1 - $._config.SLOs.apiserver.target),
            ],
            labels: {
              severity: w.severity,
              short: '%(short)s' % w,
              long: '%(long)s' % w,
            },
            annotations: {
              description: 'The API server is burning too much error budget%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'The API server is burning too much error budget.',
            },
            'for': '%(for)s' % w,
          }
          for w in $._config.SLOs.apiserver.windows
        ],
      },
      {
        name: 'kubernetes-system-apiserver',
        rules: [
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              histogram_quantile(0.01, sum without (%(namespaceLabel)s, service, endpoint) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationWarningSeconds)s
              and
              on(job, %(clusterLabel)s, instance) apiserver_client_certificate_expiration_seconds_count{%(kubeApiserverSelector)s} > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'A client certificate used to authenticate to kubernetes apiserver is expiring in less than %s%s.' % [
                (utils.humanizeSeconds($._config.certExpirationWarningSeconds)),
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Client certificate is about to expire.',
            },
          },
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              histogram_quantile(0.01, sum without (%(namespaceLabel)s, service, endpoint) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationCriticalSeconds)s
              and
              on(job, %(clusterLabel)s, instance) apiserver_client_certificate_expiration_seconds_count{%(kubeApiserverSelector)s} > 0
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              description: 'A client certificate used to authenticate to kubernetes apiserver is expiring in less than %s%s.' % [
                (utils.humanizeSeconds($._config.certExpirationCriticalSeconds)),
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Client certificate is about to expire.',
            },
          },
          {
            alert: 'KubeAggregatedAPIErrors',
            expr: |||
              sum by(%(clusterLabel)s, instance, name, reason)(increase(aggregator_unavailable_apiservice_total{%(kubeApiserverSelector)s}[1m])) > 0
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Kubernetes aggregated API {{ $labels.instance }}/{{ $labels.name }} has reported {{ $labels.reason }} errors%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubernetes aggregated API has reported errors.',
            },
          },
          {
            alert: 'KubeAggregatedAPIDown',
            expr: |||
              (1 - max by(name, namespace, %(clusterLabel)s)(avg_over_time(aggregator_unavailable_apiservice{%(kubeApiserverSelector)s}[10m]))) * 100 < 85
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'Kubernetes aggregated API {{ $labels.name }}/{{ $labels.namespace }} has been only {{ $value | humanize }}%% available over the last 10m%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'Kubernetes aggregated API is down.',
            },
          },
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeAPI',
            selector:: $._config.kubeApiserverSelector,
          },
          {
            alert: 'KubeAPITerminatedRequests',
            expr: |||
              sum by(%(clusterLabel)s) (rate(apiserver_request_terminations_total{%(kubeApiserverSelector)s}[10m])) / ( sum by(%(clusterLabel)s) (rate(apiserver_request_total{%(kubeApiserverSelector)s}[10m])) + sum by(%(clusterLabel)s) (rate(apiserver_request_terminations_total{%(kubeApiserverSelector)s}[10m])) ) > 0.20
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              description: 'The kubernetes apiserver has terminated {{ $value | humanizePercentage }} of its incoming requests%s.' % [
                utils.ifShowMultiCluster($._config, ' on cluster {{ $labels.%(clusterLabel)s }}' % $._config),
              ],
              summary: 'The kubernetes apiserver has terminated {{ $value | humanizePercentage }} of its incoming requests.',
            },
            'for': '5m',
          },
        ],
      },
    ],
  },

  _grafanaAlertsContribution+:: {
    local apiserverPrometheusRules = $.prometheusAlerts.groups[1].rules,

    groups+: [
      {
        name: 'kubernetes-system-apiserver',
        rules: [
          utils.makeGrafanaAlertBoilerplate({
            alert: rule.alert,
            expr: rule.expr,
            'for': std.get(rule, 'for', '5m'),
            labels: { [k]: rule.labels[k] for k in std.objectFields(std.get(rule, 'labels', {})) },
            annotations: { [k]: rule.annotations[k] for k in std.objectFields(std.get(rule, 'annotations', {})) },
          }, $._config)

          for rule in apiserverPrometheusRules
          if std.objectHas(rule, 'alert')
        ],
      },
    ],
  },
}
