## Objective:
- Install and configure official Tintri drivers in the PCD region

## Pre-requistes:
- Updated version of backend Tintri VMstore 
- Mount point, login details of the backend store.
- The backend should be reachable from all the hypervisor hosts (hosts with no persistent-storage role set) that are going to use the store for volumes.
- Official tintri driver files to copy on to the specific host that will be applied with persistent-storage role.

## Solution:
- Access the official repo and clone it on a central location. 
- From the PCD UI create the NFS store configuration with `custom` as driver driver as the option and the name of the driver as `cinder.volume.drivers.vmstore.nfs.VmstoreNfsDriver`.
- Configure the  key = value section for the storage backend section in the blueprints with the tintri specific settings:
  
| parameter                  | Value                                         |
| -------------------------- | --------------------------------------------- |
| volumes_dir                | /opt/pf9/etc/pf9-cindervolume-base/volumes/   |
| nas_host                   | <ip_addr_data_vm_store>                       |
| nfs_mount_options          | vers=3,proto=tcp,lookupcache=pos,nolock,noacl |
| vmstore_rest_address       | <ip_addr_of_vm-store>                         |
| nas_share_path             | /tintri/\<PATH\>                              |
| vmstore_user               | vmstore-user                                  |
| vmstore_password           | vmstore_password                              |
| vmstore_qcow2_volume       | true                                          |
| nfs_snapshot_support       | true                                          |
| nas_secure_file_operation  | false                                         |
| nas_secure_file_permission | false                                         |


- Onboard the specific hosts into pcd with persistent-store role from the UI (It will not fully converge in the UI at this state because the driver is not installed)
- Login via ssh on to the specific host with the persistent-storage role.
- Create the `vmstore` directory
```bash
mkdir /opt/pf9/pf9-cindervolume-base/lib/python3.9/site-packages/cinder/volume/drivers/vmstore
```
- Copy the cinder driver files in the vmstore directory:
```bash
cp -r vmstore-cinder-driver/* /opt/pf9/pf9-cindervolume-base/lib/python3.9/site-packages/cinder/volume/drivers/vmstore/
```
**NOTE**: Assuming the driver is downloaded and place in some directory in the same host. It can also be remote copied to the host via scp or other scripts.

- Restart the `pf9-cindervolume-base` service on all the hypervisor nodes. 
```bash
sudo systemctl restart pf9-cindervolume-base
```
- From the UI wait for the converge to complete. 
- Review the hostagent or cindervolume-base logs if required, in case converged did not happen.

## Verification:
- The actual `cinder.conf` post successful apply of the storage role with tintri backend:
```bash
[Tintri_Some_backend_name]
volume_driver = cinder.volume.drivers.vmstore.nfs.VmstoreNfsDriver
volume_backend_name = wiv-tintri
pf9_identifier_timestamp = 1747312832.3653367
nas_host = 10.102.128.2
vmstore_user = cinder
nas_share_path = /tintri/cinder
vmstore_user = SomeUser
vmstore_password = SomePassword
nfs_mount_options = vers=3,proto=tcp,lookupcache=pos,nolock,noacl
nfs_snapshot_support = true
vmstore_rest_address = SomeAddress
vmstore_qcow2_volumes = true
```
- Test by deploying a VM or creating a volume. 