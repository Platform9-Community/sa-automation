## Objective:
- Customise and onboard baremetal to PCD region in Milford region

## Pre-requisites:
- Fully operational MaaS server in the network segment
- Details of IPMI access, bond and storage VLAN IPs
- Region blueprints populated with the network host config profiles for the hosts to be onboarded.

**NOTE**: This script workflow is only certified on infrastructure that uses the native VLAN tagging enabled in the switch fabric interconnects. 

## Steps:

Download the latest MaaS automation script on to the MaaS server:
```bash
wget https://github.com/platform9/pcd-maas/archive/refs/tags/0.2.2.tar.gz
```
- Extract the tar file and inside the tar extract the `prerequisites.tar.gz` file.
```bash
tar -xvf prerequisites.tar.gz
```

- perform cmd maas login:
```bash
maas login <maas_user> http://<maas_ip>:5240/MAAS/ $(sudo maas apikey --username=<maas_user>)
```
**NOTE**: ensure there are no multiple Maas api keys for the admin user (check the UI apikeys section)

- Make the `clouds.yaml` file in the default location (/home/maa-admin/.config/openstack/clouds.yaml)
```bash

clouds:
  Milford:
    auth:
     auth_url: https://disw-qa-milford.app.pcd.platform9.com/keystone/v3
     project_name: service
     username: SomeUser
     password: <SomePassword>
     user_domain_name: default
     project_domain_name: default
    region_name: Milford
    interface: public
    identity_api_version: 3
    compute_api_version: 2
    volume_api_version: 3
    image_api_version: 2
    identity_interface: public
    volume_interface: public

```
- Modify the `machines.csv `file with the required details like the ipmi info, host ip and storage IP:
```bash
hostname,architecture,mac_addresses,power_type,power_user,power_pass,power_driver,power_address,cipher_suite_id,power_boot_type,privilege_level,k_g,ip,storage_ip
pf9-test001,amd64/generic,3c:fd:fe:b5:1a:8d,ipmi,admin,password,LAN_2_0,172.25.1.11,3,auto,ADMIN,,192.168.125.167,192.168.125.165
pf9-test002,amd64/generic,3c:fd:fe:b5:1a:8d,ipmi,admin,password,LAN_2_0,172.25.1.12,3,auto,ADMIN,,192.168.125.168,192.168.125.166
```
- Copy the `cloud-init.yaml` file from the Siemens internal repo.
- Ensure the SSH key for the MAAS server user (used to connect to deployed machines during onboarding) is added in the MAAS UI.
- Run the script:
```bash
python3 main_script.py  --maas_user maas-admin   --csv_filename machines.csv  --cloud_init_template cloud-init.yaml  --portal disw-qa  --region Milford  --environment stage  --url <region-URL>  --max_workers 5 --ssh_user maas-admin  --setup_env yes
```

## Verification:
- The onboarded host should be visible in `unauthorized` state in the PCD UI