# Integrating with Prometheus Alertmanager

## Microsoft Teams

Reference [docs](https://github.com/prometheus-msteams/prometheus-msteams/blob/master/chart/prometheus-msteams/README.md)

Add the prometheus-msteams helm repo
```
helm repo add prometheus-msteams https://prometheus-msteams.github.io/prometheus-msteams/
helm repo update
```

Create a `values.yaml` file

```
replicaCount: 1
image:
  repository: quay.io/prometheusmsteams/prometheus-msteams
  tag: v1.5.2

connectors:
# in alertmanager, this will be used as http://prometheus-msteams:2000/yourchannelname
# utilize the URL that came from creation of the webhook for the teams channel
- yourchannelname: https://outlook.office.com/webhook/xxxx/xxxx

# extraEnvs is useful for adding extra environment variables such as proxy settings
extraEnvs:
  HTTP_PROXY: http://corporateproxy:8080
  HTTPS_PROXY: http://corporateproxy:8080
container:
  additionalArgs:
    - -debug
```

Install the chart

Set your `KUBECONFIG` environment variable first.

```
helm install prometheus-msteams --namespace pf9-monitoring -f values.yaml prometheus-msteams/prometheus-msteams
```

Wait for it to come up:
```
kubectl get pods -l app=prometheus-msteams --namespace pf9-monitoring -w
```

Create an `alertmanager-teams.yaml` file:

```
global:
  resolve_timeout: 5m
route:
  group_by: ['instance', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 96h
  receiver: webhook # default receiver
  routes:
    - receiver: msteams
      matchers:
        - service=~"node-svc-checker"

receivers:
  - name: webhook
  - name: msteams
    webhook_configs:
      - url: http://prometheus-msteams:2000/yourchannelname
        send_resolved: true
```

## Slack

Create an `alertmanager.yaml` file:
```
global:
  resolve_timeout: 5m
route:
  group_by: ['instance', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 96h
  receiver: 'webhook'
  routes:
    - receiver: 'slack'
      matchers:
        - service=~"node-svc-checker"
receivers:
  - name: 'webhook'
  - name: 'slack'
    slack_configs:
      - api_url: https://hooks.slack.com/services/XXX
        channel: '#channel'
        send_resolved: true
        title: |-
         [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }} for {{ .CommonLabels.job }}
         {{- if gt (len .CommonLabels) (len .GroupLabels) -}}
           {{" "}}(
           {{- with .CommonLabels.Remove .GroupLabels.Names }}
             {{- range $index, $label := .SortedPairs -}}
               {{ if $index }}, {{ end }}
               {{- $label.Name }}="{{ $label.Value -}}"
             {{- end }}
           {{- end -}}
           )
         {{- end }}
        text: >-
         {{ range .Alerts -}}
         *Alert:* {{ .Annotations.title }}{{ if .Labels.severity }} - `{{ .Labels.severity }}`{{ end }}

         *Description:* {{ .Annotations.description }}

         *Details:*
           {{ range .Labels.SortedPairs }} • *{{ .Name }}:* `{{ .Value }}`
           {{ end }}
         {{ end }}
```

## Installation

Ensure you there is not already a custom alertmanager configuration:
```
kubectl get secret -n pf9-monitoring alertmanager-sysalert -o jsonpath="{.data.alertmanager\.yaml}" | base64 -d
```

If not, proceed by using the following commands:
```
kubectl delete -n pf9-monitoring secret alertmanager-sysalert
kubectl create secret generic alertmanager-sysalert -n pf9-monitoring --from-file=alertmanager.yaml
kubectl -n pf9-monitoring logs alertmanager-sysalert-0 -c alertmanager -f
```
