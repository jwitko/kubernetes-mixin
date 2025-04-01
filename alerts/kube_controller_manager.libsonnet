local utils = import '../lib/utils.libsonnet';

{
  _config+:: {
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system-controller-manager',
        rules: [
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeControllerManager',
            selector:: $._config.kubeControllerManagerSelector,
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
