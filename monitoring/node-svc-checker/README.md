# Node Service Monitoring

Solution to actively monitor an arbitrary operating system component of one or more PMK nodes and
to take Scheduling action(s) if that component is deemed unhealthy.

## Overview

The architecture is as follows.

Node Monitor Script
 * executable that exists on nodes to be monitored
 * uses whatever internal logic is necessary to monitor any arbitray components of the node
 * will exit with exit code of zero when said component(s) are healthy
 * will exit with non-zero exit code when not healhty
 * any output to stderr is assumed to be an internal failure of the monitoring logic and considered fatal, causing the overall monitoring actions to exit 1 (CrashLoopBackOff)

Daemonset
 * runs on all or select nodes via nodeSelector label
 * exectutes a wrapper control process which continually invokes the Node Monitor Script above
 * invocation frequency of the monitor script can be customized
 * when failures are detected, a customizable failure threshold exists to avoid taking action on "flapping" conditions
 * will optionally cordon a node once the failure threshold is exceeded
 * will optionally drain a node once the failure threshold is exceeded
 * will optionally taint a node once the failure threshold is exceeded
 * will undo all 3 of the above actions when the failure clears


Helm Chart
 * handles delivery and lifecycle management of manifests to PMK cluster(s)

## Prerequisites

While the components can be easily installed via `helm` command, a wrapper leveraging `just` command recipes has been used.

To install `just` use one of these [packages](https://github.com/casey/just#packages)

At any time to view the recipes available in the `justfile` type `just`:

```
$ just
Available recipes:
    generate_values
    template
    install
    upgrade
    uninstall
    list
```

Export your `KUBECONFIG` environment variable to point to the path of the target cluster's local kubeconfig file.

```
export KUBECONFIG=/some/file.yaml
```

## Instalation

Since you will use helm to deploy to the cluster, you first need to make any customizations to the values of the chart.

Generate a values file to customize:
```
just generate_values
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
| checker.nodeTaint.key | string | when `checker.taintNodeOnFailure` is true, use this as the taint value |
| checker.nodeTaint.key | string | when `checker.taintNodeOnFailure` is true, use this as the taint effect |
| nodeSelector | string | when set, will determine which node(s) the DaemonSet is run on |


Once customizations, have been made, review the manifests by rendering the helm templates. This
will NOT deploy them to the cluster, simply renders them to the console:

```
just template
```

Once satisfied, deploy the manifests to the cluster.

```
$ just install
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
$ just list
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
just uninstall
```

## Upgrade

```
just upgrade
```