## Objective:
- Setup the PCD environment such that workload deployed from specific tenant should only be applied to specific set of hosts with the environment. 
- No other VM should be able get spawned on those designated hosts.

## Pre-requisites:
- Fully configured PCD environment. 
- Required tenant setup along with necessary flavors and images in place. 
  
## Steps:
-  Create a cluster with set of hypervisor hosts from the UI which will create the host aggregate:
```bash
0$ openstack aggregate show testresource
+-------------------+------------------------------------------------------------------------------------------------------------------+
| Field             | Value                                                                                                            |
+-------------------+------------------------------------------------------------------------------------------------------------------+
| availability_zone | testresource                                                                                                       |
| created_at        | 2025-06-19T07:20:37.000000                                                                                       |
| deleted_at        | None                                                                                                             |
| hosts             | 046b266e-aba7-47a2-a0b3-e786e429bb21, 8e899c21-0a6b-4fc9-a6ac-e866d84560df, b492f050-662c-4072-8d7a-3e41f9fa98e6 |
| id                | 1                                                                                                                |
| is_deleted        | False                                                                                                            |
| name              | testresource                                                                                                       |
| properties        | pf9-managed='true'                                                                                               |
| updated_at        | None                                                                                                             |
| uuid              | 6a9edd85-fc3c-4079-bbaf-74f640273e73                                                                             |
+-------------------+------------------------------------------------------------------------------------------------------------------+
```
- Set the testresource tenant ID as property to aggregate:
```bash
$ openstack aggregate set --property filter_tenant_id=6f96f506b8b54c1798335def751dcb46 testresource
$ openstack aggregate show testresource
+-------------------+------------------------------------------------------------------------------------------------------------------+
| Field             | Value                                                                                                            |
+-------------------+------------------------------------------------------------------------------------------------------------------+
| availability_zone | testresource                                                                                                       |
| created_at        | 2025-06-19T07:20:37.000000                                                                                       |
| deleted_at        | None                                                                                                             |
| hosts             | 046b266e-aba7-47a2-a0b3-e786e429bb21, 8e899c21-0a6b-4fc9-a6ac-e866d84560df, b492f050-662c-4072-8d7a-3e41f9fa98e6 |
| id                | 1                                                                                                                |
| is_deleted        | False                                                                                                            |
| name              | testresource                                                                                                       |
| properties        | filter_tenant_id='6f96f506b8b54c1798335def751dcb46', pf9-managed='true'                                          |
| updated_at        | None                                                                                                             |
| uuid              | 6a9edd85-fc3c-4079-bbaf-74f640273e73                                                                             |
+-------------------+------------------------------------------------------------------------------------------------------------------+
```

- As an admin User linked to the targeted tenant/project, from the UI or using the command line create a flavor  which should be private and should have the metadata set `filter_tenant_id=<tenant-id>`. 
- From the UI when creating the flavor, enabling the `matching hosts aggregates `flags should help listing all the aggregates from which you can then select the `assign metadata` button to add it as the metadata.

## Verification:
- Try scheduling an instance using the the flavor tagged with the tenantID from the same tenant/project.
- Scheduling VM from another project to same aggregate should fail.
- Scheduling VM from another project using the tagged flavor should not work.

## Reference:
https://docs.openstack.org/nova/victoria/admin/aggregates.html#tenant-isolation-with-placement 