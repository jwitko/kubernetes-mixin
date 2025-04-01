local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    kubeSchedulerSelector: 'job="kube-scheduler"',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-scheduler',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeScheduler',
            selector:: $._config.kubeSchedulerSelector,
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
