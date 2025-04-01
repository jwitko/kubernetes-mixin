{
  mapRuleGroups(f): {
    groups: [
      group {
        rules: [
          f(rule)
          for rule in super.rules
        ],
      }
      for group in super.groups
    ],
  },

  humanizeSeconds(s)::
    if s > 60 * 60 * 24
    then '%.1f days' % (s / 60 / 60 / 24)
    else '%.1f hours' % (s / 60 / 60),

  // Handle adding `group left` to join labels into rule by wrapping the rule in () * on(xxx) group_left(xxx) kube_xxx_labels
  // If kind of rule is not defined try to detect rule type by alert name
  wrap_rule_for_labels(rule, config):
    // Detect Kind of rule from name unless hidden `kind field is passed in the rule`
    local kind =
      if 'kind' in rule then rule.kind
      // Handle Alerts
      else if std.objectHas(rule, 'alert') then
        if std.startsWith(rule.alert, 'KubePod') then 'pod'
        else if std.startsWith(rule.alert, 'KubeContainer') then 'pod'
        else if std.startsWith(rule.alert, 'KubeStateful') then 'statefulset'
        else if std.startsWith(rule.alert, 'KubeDeploy') then 'deployment'
        else if std.startsWith(rule.alert, 'KubeDaemon') then 'daemonset'
        else if std.startsWith(rule.alert, 'KubeHpa') then 'horizontalpodautoscaler'
        else if std.startsWith(rule.alert, 'KubeJob') then 'job'
        else 'none'
      else 'none';

    local labels = {
      join_labels: if std.objectHas(config, '%ss_join_labels' % kind) then config['%ss_join_labels' % kind] else [],
      // since the label 'job' is reserved, the resource with kind Job uses the label 'job_name' instead
      on_labels: [
        '%s' % (if kind == 'job' then 'job_name' else kind),
        '%s' % config.namespaceLabel,
        if std.objectHas(config, 'clusterLabel') then '%s' % config.clusterLabel else 'cluster',
      ],
      metric: 'kube_%s_labels' % kind,
    };

    // Failed to identify kind - return raw rule
    if kind == 'none' then rule
    // No join labels passed in the config - return raw rule
    else if std.length(labels.join_labels) == 0 then rule
    // Wrap expr with join group left
    else
      rule {
        local expr = super.expr,
        expr: '(%(expr)s) * on (%(on)s) group_left(%(join)s) %(metric)s' % {
          expr: expr,
          on: std.join(',', labels.on_labels),
          join: std.join(',', labels.join_labels),
          metric: labels.metric,
        },
      },

  // if showMultiCluster is true in config, return the string, otherwise return an empty string
  // With a fallback when the field doesn't exist
  ifShowMultiCluster(config, string)::
    if std.objectHas(config, 'showMultiCluster') && config.showMultiCluster
    then string
    else '',

  // Function to create the Grafana alert data structure boilerplate
  makeGrafanaAlertBoilerplate(promRule, config)::
    local evaluatorType = 'gt';  // Default, potentially extract from promRule.expr later if complex parsing is desired
    local evaluatorThreshold = 0;  // Default, potentially extract from promRule.expr later
    local reducerType = 'last';  // Default, may need adjustment based on query

    // Ensure config has required values with defaults
    local configWithDefaults = config {
      grafanaDatasourceUid: if std.objectHas(config, 'grafanaDatasourceUid') then config.grafanaDatasourceUid else 'P09C4D52DEC9B98E6',
      grafanaIntervalMs: if std.objectHas(config, 'grafanaIntervalMs') then config.grafanaIntervalMs else 60000,
      grafanaNoDataState: if std.objectHas(config, 'grafanaNoDataState') then config.grafanaNoDataState else 'OK',
      grafanaExecErrState: if std.objectHas(config, 'grafanaExecErrState') then config.grafanaExecErrState else 'Error',
    };

    // Base Grafana alert structure (inner part)
    local grafanaAlertData = {
      title: promRule.alert,
      condition: 'C',
      data: [
        {
          refId: 'A',
          queryType: '',
          relativeTimeRange: {
            from: 300,
            to: 0,
          },
          datasourceUid: configWithDefaults.grafanaDatasourceUid,
          model: {
            editorMode: 'code',
            // Force evaluation of the original Prometheus expr string HERE
            local evaluatedExpr = promRule.expr,
            expr: evaluatedExpr,  // Assign the evaluated string
            intervalMs: configWithDefaults.grafanaIntervalMs,
            legendFormat: '__auto',
            maxDataPoints: 43200,
          },
        },
        {
          refId: 'B',
          queryType: '',
          relativeTimeRange: {
            from: 0,
            to: 0,
          },
          datasourceUid: '-100',  // Expression datasource
          model: {
            conditions: [
              {
                evaluator: {
                  params: [evaluatorThreshold],
                  type: evaluatorType,
                },
                operator: {
                  type: 'and',
                },
                query: {
                  params: ['A'],
                },
                reducer: {
                  type: reducerType,
                },
                type: 'query',
              },
            ],
            datasource: { type: '__expr__', uid: '-100' },
            expression: 'A',  // Reduce expression
            intervalMs: configWithDefaults.grafanaIntervalMs,
            maxDataPoints: 43200,
            reducer: reducerType,
            refId: 'B',
            type: 'reduce',
          },
        },
        {
          refId: 'C',
          queryType: '',
          relativeTimeRange: {
            from: 0,
            to: 0,
          },
          datasourceUid: '-100',  // Expression datasource
          model: {
            conditions: [
              {
                evaluator: {
                  // This threshold comparison happens in the expression below
                  params: [0],  // Placeholder, actual comparison in math expression
                  type: evaluatorType,  // Keep original type for reference if needed
                },
                operator: {
                  type: 'and',
                },
                query: {
                  params: ['B'],
                },
                reducer: {
                  type: 'last',
                },
                type: 'query',
              },
            ],
            datasource: { name: 'Expression', type: '__expr__', uid: '__expr__' },
            // Construct the final math expression (e.g., $B > 0)
            // Assuming evaluatorThreshold/Type reflect the simple comparison for now
            expression:
              if evaluatorType == 'gt' then '$B > %f' % evaluatorThreshold
              else if evaluatorType == 'lt' then '$B < %f' % evaluatorThreshold
              else if evaluatorType == 'eq' then '$B == %f' % evaluatorThreshold
              else if evaluatorType == 'neq' then '$B != %f' % evaluatorThreshold
              // Add more complex parsing/handling here if needed based on promRule.expr
              else '$B > 0',  // Default condition
            intervalMs: configWithDefaults.grafanaIntervalMs,
            maxDataPoints: 43200,
            type: 'math',
          },
        },
      ],
      // Add uid, no_data_state, exec_err_state from config if they exist
      uid: ''  // uid seems empty in the example, can be generated if needed
           + (if std.objectHas(config, 'grafanaNoDataState') then { no_data_state: config.grafanaNoDataState } else {})
           + (if std.objectHas(config, 'grafanaExecErrState') then { exec_err_state: config.grafanaExecErrState } else {}),
    };

    // Construct the final Grafana rule object
    {
      expr: '',  // Outer expr is empty in Grafana format
      'for': std.get(promRule, 'for', '5m'),  // Copy 'for' duration
      labels: std.get(promRule, 'labels', {}),  // Copy labels

      // Force evaluation of annotations in the current context before copying
      // Create a new object by iterating through the keys of the original annotations
      // Accessing promRule.annotations[key] forces evaluation in the calling context
      local evaluatedAnnotations = {
        [key]: promRule.annotations[key]
        for key in std.objectFields(std.get(promRule, 'annotations', {}))
      },
      annotations: evaluatedAnnotations,  // Assign the fully evaluated annotations

      grafana_alert: grafanaAlertData,  // Embed the Grafana-specific data
    },
}
