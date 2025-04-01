local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    kubeProxySelector: 'job="kube-proxy"',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-kube-proxy',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeProxy',
            selector:: $._config.kubeProxySelector,
          },
        ],
      },
    ],
  },

  _grafanaAlertsContribution:: {
    [group.name]: [
      utils.makeGrafanaAlertBoilerplate(rule, $._config)
      for rule in group.rules
      if std.objectHas(rule, 'alert')
    ]
    for group in $.prometheusAlerts.groups
  },
}
