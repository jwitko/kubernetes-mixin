{
  _config+:: {
    // Default cluster label
    clusterLabel: 'cluster',

    // Default selectors
    cadvisorSelector: 'job="kubelet"',
    kubeletSelector: 'job="kubelet"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeApiserverSelector: 'job="apiserver"',
    kubeProxySelector: 'job="kube-proxy"',
    namespaceLabel: 'namespace',
    prefixedNamespaceSelector: 'namespace!=""',
    notKubeDnsCoreDnsSelector: 'job!~"kube-dns|coredns"',

    // Sample times
    volumeFullPredictionSampleTime: '6h',

    // PV excluded selector
    pvExcludedSelector: 'label_excluded_from_alerts="true"',

    // Default Grafana configuration
    grafanaDatasourceUid: 'P09C4D52DEC9B98E6',
    grafanaIntervalMs: 60000,
    grafanaNoDataState: 'OK',
    grafanaExecErrState: 'Error',

    // Default join labels
    common_join_labels: [],
    pods_join_labels: [],
    statefulsets_join_labels: [],
    deployments_join_labels: [],
    daemonsets_join_labels: [],
    horizontalpodautoscalers_join_labels: [],
    jobs_join_labels: [],

    // Default kubeDaemonSetRolloutStuckFor
    kubeDaemonSetRolloutStuckFor: '15m',

    // Default kubeJobTimeoutDuration
    kubeJobTimeoutDuration: 12 * 60 * 60,
  },
}
