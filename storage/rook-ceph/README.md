# Rook Ceph

## Pre-requisites

1. Disk prep

Provide at least 3 disks for rook-ceph to utilize. In a 5 node cluster, with 2 masters and 3 workers, 3 disks, one on each worker will suffice as bare minimum.
Wipe the disk block devices using the `clean_disk.sh` script in this repo. For example, on the node below, I wished to initialize the `/dev/vdb` block device for rook-ceph:

```
root@jmiller-calicopmk-follower-1:~# ./clean_disk.sh vdb
Creating new GPT entries in memory.
GPT data structures destroyed! You may now partition the disk using fdisk or
other utilities.
100+0 records in
100+0 records out
104857600 bytes (105 MB, 100 MiB) copied, 0.662174 s, 158 MB/s
root@jmiller-calicopmk-follower-1:~#
```

2. KUBECONFIG

Export your KUBECONFIG environment variable to point to the path of the kubeconfig file to be used for install rook-ceph into the appropriate cluster.

```
export KUBECONFIG=~/Downloads/my_cluster.yaml
kubectl cluster-info
```

## Installation

1. Set up helm repo

Run the following command to set up the required helm components locally on your workstation

```
cd ceph-operator
just setup
```

2. Configuration

Make any configuration changes as needed by editing the `ceph-operator/justfile' section:

```
# Customize any of the below
namespace := "rook-ceph"
log_level := "INFO"
ceph_cluster_name := "rook-ceph"
chart_name := "rook-ceph"
chart_repo := "rook-release"
chart_version := "v1.11.7"
version_safe := replace(chart_version,'.','-')
repo_url := "https://charts.rook.io/release"
monitoring_enabled := "false"
rbd_enabled := "true"
cephfs_enabled := "true"
crds_enabled := "true"
# below 3 lines are only required for multi homed cluster
multi_homed_networks := "false"
ceph_public_network := "10.10.10.0/24"
ceph_cluster_network := "10.10.20.0/24"
# end customizations
```

3. Deploy the operator

Install the operator with the following commands

```
cd ceph-operator
just generate_values
just install
just list
```

The output will look similar to:

```
Namespace may already exist, in which case ignore errors
kubectl create ns rook-ceph --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml || true
namespace/rook-ceph created
for master in 172.29.20.156 172.29.21.130 172.29.21.188 ; do echo $master ; kubectl label --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml nodes $master role=ceph-operator-node --overwrite=true || true ; done
172.29.20.156
node/172.29.20.156 labeled
172.29.21.130
node/172.29.21.130 labeled
172.29.21.188
node/172.29.21.188 labeled
for worker in 172.29.20.218 172.29.20.47 172.29.21.117 ; do echo $worker ; kubectl label --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml nodes $worker role=ceph-storage-node --overwrite=true || true ; done
172.29.20.218
node/172.29.20.218 labeled
172.29.20.47
node/172.29.20.47 labeled
172.29.21.117
node/172.29.21.117 labeled
if [[ "false" == "true" ]]; then envsubst < rook-config-override.yaml.tmpl | kubectl apply --namespace rook-ceph --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml -f - ; fi
helm install rook-ceph rook-release/rook-ceph   --version v1.11.7   --set crds.enabled=true   --set monitoring.enabled=false   --set logLevel=INFO   --set enableRbdDriver=true   --set enableCephfsDriver=true   --values values_v1-11-7.yaml   --values values_tolerations.yaml  --namespace rook-ceph --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml --kube-context default
NAME: rook-ceph
LAST DEPLOYED: Mon Oct  9 08:49:05 2023
NAMESPACE: rook-ceph
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Rook Operator has been installed. Check its status by running:
  kubectl --namespace rook-ceph get pods -l "app=rook-ceph-operator"

Visit https://rook.io/docs/rook/latest for instructions on how to create and configure Rook clusters

Important Notes:
- You must customize the 'CephCluster' resource in the sample manifests for your cluster.
- Each CephCluster must be deployed to its own namespace, the samples use `rook-ceph` for the namespace.
- The sample manifests assume you also installed the rook-ceph operator in the `rook-ceph` namespace.
- The helm chart includes all the RBAC required to create a CephCluster CRD in the same namespace.
- Any disk devices you add to the cluster in the 'CephCluster' must be empty (no filesystem and no partitions).
[jmiller@euclid: ~/Projects/PF9/sa-automation/storage/rook-ceph/ceph-operator] [main|✚ 6…29] ✔
08:49 $ k cluster-info
Kubernetes control plane is running at https://10.149.101.135
CoreDNS is running at https://10.149.101.135/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://10.149.101.135/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

Validate the operator is running:

```
$ kubectl --namespace rook-ceph get pods -l "app=rook-ceph-operator"
NAME                                  READY   STATUS    RESTARTS   AGE
rook-ceph-operator-74f44888f4-5cpsv   1/1     Running   0          3m50s
```

4. Deploy a rook-ceph cluster

Run the following command to set up the required helm components locally on your workstation

```
cd ceph-cluster
just setup
```

5. Configuration

Make any configuration changes as needed by editing the `ceph-cluster/justfile' section:

Note: The namespace should be the same as that of the ceph-operator

```
# Customize any of the below
namespace := "rook-ceph"
ceph_cluster_name := "rook-ceph"
chart_name := "rook-ceph-cluster"
chart_repo := "rook-release"
chart_version := "v1.11.7"
version_safe := replace(chart_version,'.','-')
snapshotclass_version := "v6.2.1"
repo_url := "https://charts.rook.io/release"
monitoring_enabled := "false"
toolbox_enabled := "true"
dashboard_enabled := "true"
dashboard_port := "32443"
allow_multiple_mon_per_node := "false"
mon_count := "3"
disable_crashcollector := "true"
storageclass_to_test := "ceph-block"
enable_cephfs_snapshots := "false"
enable_rbd_snapshots := "false"
# end customizations
```

Configure the disks that you prepared earlier.

```
cp node_storage.yaml.example node_storage.yaml
vi node_storage.yaml
```

Edit the `node_storage.yaml` file and add the disks you initialized earlier. Use the node name of the workers, as they appear from `kubectl get nodes`

```
$ cat node_storage.yaml
cephClusterSpec:
  storage:
    nodes:
      - name: "172.29.20.218"
        devices:
          - name: "vdb"
      - name: "172.29.20.47"
        devices:
          - name: "vdb"
      - name: "172.29.21.117"
        devices:
          - name: "vdb"
```

6. Deploy the cluster CRD via helm

Run the following command

```
just generate_values
just install
just list_clusters
```

The output will look similar to:

```
$ just install
Namespace may already exist, in which case ignore errors
kubectl create ns rook-ceph --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml || true
namespace/rook-ceph created
helm install rook-ceph-cluster rook-release/rook-ceph-cluster   --version v1.11.7   --set clusterName=rook-ceph   --set cephClusterSpec.mon.allowMultiplePerNode=false   --set cephClusterSpec.mon.count=3   --set cephClusterSpec.dashboard.enabled=true   --set cephClusterSpec.dashboard.port=32443   --set monitoring.enabled=false   --set toolbox.enabled=true   --set cephClusterSpec.storage.useAllNodes=false   --set cephClusterSpec.storage.useAllDevices=false   --set cephClusterSpec.crashCollector.disable=true   --set cephFileSystemVolumeSnapshotClass.enabled=false   --set cephBlockPoolsVolumeSnapshotClass.enabled=false   --values values_v1-11-7.yaml   --values network_connections.yaml   --values node_storage.yaml   --values values_tolerations.yaml  --namespace rook-ceph --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml --kube-context default
NAME: rook-ceph-cluster
LAST DEPLOYED: Tue Oct 10 08:05:28 2023
NAMESPACE: rook-ceph
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Ceph Cluster has been installed. Check its status by running:
  kubectl --namespace rook-ceph get cephcluster

Visit https://rook.io/docs/rook/latest/CRDs/ceph-cluster-crd/ for more information about the Ceph CRD.

Important Notes:
- You can only deploy a single cluster per namespace
- If you wish to delete this cluster and start fresh, you will also have to wipe the OSD disks using `sfdisk`
```

You can follow the installation with the following command, waiting until all pods are running

```
kubectl get pods -n rook-ceph -w
```

## Validation

You can list clusters and get their status with the following

```
$ just list_clusters
helm list --filter rook-ceph-cluster --all-namespaces --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml --kube-context default
NAME                    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                           APP VERSION
rook-ceph-cluster       rook-ceph       1               2023-10-10 08:10:31.209637327 -0400 EDT deployed        rook-ceph-cluster-v1.11.7       v1.11.7
kubectl --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml get pods -l 'app=rook-ceph-operator' -A
NAMESPACE   NAME                                  READY   STATUS    RESTARTS   AGE
rook-ceph   rook-ceph-operator-74f44888f4-b6bvq   1/1     Running   0          46h
kubectl --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml get cephcluster -A
NAMESPACE   NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH      EXTERNAL   FSID
rook-ceph   rook-ceph   /var/lib/rook     3          46h   Ready   Cluster created successfully   HEALTH_OK              954bf80c-b82b-4227-8855-a9f10b56c6cc
```

To obtain a more detailed status:

```
$ just status
kubectl --namespace rook-ceph --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml exec -it rook-ceph-tools-667d6448d8-6p7vv -- bash -c 'ceph status; ceph osd tree; ceph osd status'
  cluster:
    id:     954bf80c-b82b-4227-8855-a9f10b56c6cc
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum a,b,c (age 46h)
    mgr: a(active, since 4h), standbys: b
    mds: 1/1 daemons up, 1 hot standby
    osd: 3 osds: 3 up (since 10h), 3 in (since 46h)
    rgw: 1 daemon active (1 hosts, 1 zones)

  data:
    volumes: 1/1 healthy
    pools:   12 pools, 169 pgs
    objects: 398 objects, 484 KiB
    usage:   234 MiB used, 60 GiB / 60 GiB avail
    pgs:     169 active+clean

  io:
    client:   852 B/s rd, 1 op/s rd, 0 op/s wr

ID  CLASS  WEIGHT   TYPE NAME               STATUS  REWEIGHT  PRI-AFF
-1         0.05846  root default
-5         0.01949      host 172-29-20-218
 1    hdd  0.01949          osd.1               up   1.00000  1.00000
-7         0.01949      host 172-29-20-47
 2    hdd  0.01949          osd.2               up   1.00000  1.00000
-3         0.01949      host 172-29-21-117
 0    hdd  0.01949          osd.0               up   1.00000  1.00000
ID  HOST            USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE
 0  172.29.21.117  70.3M  19.9G      0        0       3      106   exists,up
 1  172.29.20.218  84.4M  19.9G      0        0       0        0   exists,up
 2  172.29.20.47   78.8M  19.9G      0        0       0        0   exists,up
 ```

 Once the cluster is up and healthy you can test creation of a PVC using the ceph-block (rbd) storage class:

 ```
 $ just test
envsubst < test-pvc.yaml | kubectl apply --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml -f -
persistentvolumeclaim/busyboxpvc1 created
pod/busyboxtest created
kubectl --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml wait -n default --for=condition=ready pod/busyboxtest --timeout=120s
pod/busyboxtest condition met
kubectl --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml get pvc -l 'app=busyboxtest'
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS        AGE
busyboxpvc1   Bound    pvc-613ecec4-9ddc-48bb-af60-a6b6d74d10e3   500Mi      RWX            ceph-filesystem     7s
```

Clean up the POD and PVC

```
$ just clean_test
envsubst < test-pvc.yaml | kubectl delete --context default --kubeconfig /home/jmiller/Downloads/calico-rspc.yaml --force=true -f -
Warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the cluster indefinitely.
persistentvolumeclaim "busyboxpvc1" force deleted
pod "busyboxtest" force deleted
```

## Diagnostics

There is a comprehensive diagnostics gathering tool from 42on that can be run to collect ceph cluster information, configuration and metrics

It is called [ceph-collect](https://github.com/42on/ceph-collect) on github

To run this command and copy the resulting output file locally run:

```
just ceph_collect
```

## Uninstall

**Danger**
To destroy the ceph cluster and all data and remove it completely run the following

```
cd ceph-cluster
just uninstall
cd ../ceph-operator
just uninstall
just destroy_crds
```

Next, you will have to remove the `/var/lib/rook/rook-ceph` from each of the nodes.
