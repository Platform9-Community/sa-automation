# Node Service Monitoring

Solution to actively monitor an arbitrary operating system component of one or more PMK nodes and
to take Scheduling action(s) if that component is deemed unhealthy.

## Overview

The architecture is as follows.

⚙ Node Monitor Script
 * executable that exists on nodes to be monitored
 * uses whatever internal logic is necessary to monitor any arbitrary components of the node
 * will exit with exit code of zero when said component(s) are healthy
 * will exit with non-zero exit code when not healthy
 * any output to stderr is assumed to be an internal failure of the monitoring logic and considered fatal, causing the overall monitoring actions to exit 1 (CrashLoopBackOff)

⚙ Daemonset
 * runs on all or select nodes via nodeSelector label
 * executes a wrapper control process which continually invokes the Node Monitor Script above
 * invocation frequency of the monitor script can be customized
 * when failures are detected, a customizable failure threshold exists to avoid taking action on "flapping" conditions
 * will optionally cordon a node once the failure threshold is exceeded
 * will optionally drain a node once the failure threshold is exceeded
 * will optionally taint a node once the failure threshold is exceeded
 * will undo all 3 of the above actions when the failure clears

⚙ Helm Chart
 * handles delivery and lifecycle management of manifests to PMK cluster(s)

## Prerequisites

Install `helm` if necessary:

```
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

While the components can be easily installed via `helm` command, a wrapper leveraging `make` command targets has been used.

At any time to view the targets available type `make`:

```
$ make
Run one of the following targets: generate_values, template, install, upgrade uninstall, list
```

Export your `KUBECONFIG` environment variable to point to the path of the target cluster's local kubeconfig file.

```
export KUBECONFIG=/some/file.yaml
```

Adjust the `NAMESPACE` variable in the `Makefile` to the namespace you with to deploy the helm chart.

```
NAMESPACE := nsc-system
```

## Installation

Since you will use helm to deploy to the cluster, you first need to make any customizations to the values of the chart.

Generate a values file to customize:
```
make generate_values
```

A file such as `values_0-1-0.yaml` is generated. Determine any customizations necessary, edit the file accordingly. While there are numerous other values that can be customized, the following are the most important and likely ones to consider.

| Value | Type | Description |
| --- | --- | --- |
| namespace | string | namespace to deploy into |
| checker.debug | boolean | set to true to enable debug level logs |
| checker.nodeCheckScriptPath | string | the path to the monitoring script file on the node(s) |
| checker.scriptPeriodSec | integer | the frequency in seconds at which the monitoring script will be invoked |
| checker.failureThreshold | integer | the number of sequential times the monitoring script can return z non-zero exit code before a failure is declared and actions are taken |
| checker.cordonNodeOnFailure | bool | if true, the node will be cordoned when a failure is declared |
| checker.drainNodeOnFailure | bool | if true, the node will be drained when a failure is declared |
| checker.taintNodeOnFailure | bool | if true, the node will be tainted with a user defined taint when a failure is declared |
| checker.nodeTaint.key | string | when `checker.taintNodeOnFailure` is true, use this as the taint key |
| checker.nodeTaint.value | string | when `checker.taintNodeOnFailure` is true, use this as the taint value |
| checker.nodeTaint.effect | string | when `checker.taintNodeOnFailure` is true, use this as the taint effect |
| nodeSelector | string | when set, will determine which node(s) the DaemonSet is run on |


Once customizations, have been made, review the manifests by rendering the helm templates. This
will NOT deploy them to the cluster, simply renders them to the console:

```
make template
```

Once satisfied, deploy the manifests to the cluster.

```
make install
helm install node-svc-checker-0-1-0 ./helm/node-svc-checker   --version 0.1.0   --create-namespace   --values values_0-1-0.yaml  --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml --kube-context default
NAME: node-svc-checker-0-1-0
LAST DEPLOYED: Wed Dec  6 09:28:19 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

Review the installation

```
make list
helm list --filter node-svc-checker --all-namespaces --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml --kube-context default
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
node-svc-checker-0-1-0  default         1               2023-12-06 09:28:19.126562358 -0500 EST deployed        node-svc-checker-0.1.0  0.1.0
kubectl --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml get pods -o wide -l app.kubernetes.io/name=node-svc-checker -A
NAMESPACE   NAME                     READY   STATUS    RESTARTS   AGE     IP              NODE            NOMINATED NODE   READINESS GATES
nsc         node-svc-checker-2bfc6   1/1     Running   0          4m36s   10.20.193.121   172.29.21.130   <none>           <none>
nsc         node-svc-checker-7pnxg   1/1     Running   0          4m36s   10.20.156.176   172.29.21.188   <none>           <none>
nsc         node-svc-checker-9x6x6   1/1     Running   0          4m36s   10.20.181.202   172.29.20.218   <none>           <none>
nsc         node-svc-checker-hk9q5   1/1     Running   0          4m36s   10.20.55.49     172.29.20.47    <none>           <none>
nsc         node-svc-checker-vqdrv   1/1     Running   0          4m36s   10.20.151.234   172.29.20.156   <none>           <none>
nsc         node-svc-checker-w7vx8   1/1     Running   0          4m36s   10.20.126.183   172.29.21.117   <none>           <none>
```

## Uninstall

```
make uninstall
```

## Upgrade

```
make upgrade
```

## Troubleshooting

Descriptive logs can be viewed via `kubectl logs -f <POD>`
If more logging is necessary, redeploy with `checker.debug=true`

```
[✅OK] return code was zero.
INFO: Running /tmp/foo.sh
[✅OK] return code was zero.
INFO: Running /tmp/foo.sh
[💥FAIL] non-zero return code. Noticed 1 times. (threshold is 4)
INFO: Running /tmp/foo.sh
[💥FAIL] non-zero return code. Noticed 2 times. (threshold is 4)
INFO: Running /tmp/foo.sh
[💥FAIL] non-zero return code. Noticed 3 times. (threshold is 4)
INFO: Running /tmp/foo.sh
[💥FAIL] non-zero return code. Noticed 4 times. (threshold is 4)
⚠ WARN: Detected the monitored service is down!
⚠ WARN: Cordoning node 172.29.21.117
node/172.29.21.117 cordoned
⚠ WARN: Draining node 172.29.21.117 and adding annotation [node-svc-checker-drain-state=drainActive]
node/172.29.21.117 already cordoned
```

Once cordoning of the node has taken place, you will see something similar to:
```
$ kubectl get nodes
NAME            STATUS                     ROLES    AGE    VERSION
172.29.20.156   Ready                      master   211d   v1.26.8
172.29.20.218   Ready                      worker   211d   v1.26.8
172.29.20.47    Ready                      worker   3d1h   v1.26.8
172.29.21.117   Ready,SchedulingDisabled   worker   3d1h   v1.26.8
172.29.21.130   Ready                      master   211d   v1.26.8
172.29.21.188   Ready                      master   211d   v1.26.8
```

The `Ready` status above on the `172.29.21.117` node is unavoidable and a result of Kubelet being healthy on the node.

When the node has been tainted, cordoned and drained, you will see node taints such as:
```
Taints:
  node.kubernetes.io/unschedulable:NoSchedule
  nodeServiceCheckFailed=true:NoSchedule
```

Whether or not the node has been drained is stored as an annotation:

```
node-svc-checker-drain-state: drainActive
```

When the failure clears, you should see this in the logs:
```
INFO: Running /tmp/foo.sh
[💥FAIL] non-zero return code. Noticed 347 times. (threshold is 4)
⚠ WARN: Detected the monitored service is down!
INFO: Running /tmp/foo.sh
[✅OK] return code was zero.
INFO: Uncordoning node 172.29.21.117
node/172.29.21.117 uncordoned
INFO: Adding annotation [node-svc-checker-drain-state=drainNotActive] to node 172.29.21.117
node/172.29.21.117 annotate
INFO: Removing taint from node 172.29.21.117
node/172.29.21.117 untainted
INFO: Running /tmp/foo.sh
[✅OK] return code was zero.
INFO: Uncordoning node 172.29.21.117
node/172.29.21.117 uncordoned
```

## Prometheus Alertmanager Integration

There is a [guide in this repo](./alertmanager/README.md) for integrating with Prometheus Alertmanager.

