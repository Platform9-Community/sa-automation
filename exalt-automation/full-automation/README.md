# Adding and deploying a machine to MAAS server, then PCD joining with an automated script 
 

### This automation process is split into two sections: 

- Automate the process of enrolling baremetals into MaaS 
- Onboarding is done by triggering Ansible playbooks. 

 

 

### How to use?

Download the script and prerequisite files into the same directory.
You need to create/provide the following files according to your environment before running the script you can use the templates provided in the prerequisites folder:

    1. machines_template.csv
    2. cloud-init-template.yaml

#### Prerequisites: 

    1. Maas cli login
 
        sudo maas login <maas_user> http://<maas_ip>:5240/MAAS/ $(sudo maas apikey --generate --username=<maas_user>)

    2. Clouds.yaml created in /{home}/.config/openstack/clouds.yaml 

    3. Set up the  environment for PCD onboarding by running the script pcd_ansible-pcd_develop/setup-local.sh

       sudo bash script pcd_ansible-pcd_develop/setup-local.sh
   
#### Run the script:  


    sudo python3 main_script.py \
    --maas_user admin \
    --csv_filename machines.csv \
    --cloud_init_template cloud-init.yaml \
    --portal exalt-pcd \
    --region jrs \
    --environment stage \
    --url https://exalt-pcd-jrs.app.qa-pcd.platform9.com/ \
    --max_workers 5 \
    --ssh_user ubuntu

###### maas_user: MAAS admin username.
###### csv_filename: CSV file path.
###### cloud_init_template: Cloud-init template YAML path.
###### max_workers: Maximum number of concurrent threads for provisioning.
###### ssh_user: SSH user for Ansible.



 
 
##### Script Functionality: 

###### 1. It will add the machines to MAAS and commission them.

###### 2. When in ready state, it will generate a cloud-init file for each machine with the IP specified for each one from the CSV file,it will be generated in the tmp directory,and then deploy the OS.  

###### 3. After the deployment is done and successful, the onboarding process will begin. 
###### 4. Generating vars.yaml using Jinja2 

    - Loads a template (vars_template.j2) and fills it with the extracted data. 

    - Saves the rendered YAML to vars.yml. 

###### 5. Copying vars.yml to Ansible Playbook Directory 
       It will copy the vars file to user_resource_examples/templates/host_onboard_data.yaml.j2 	where this file will be used by the ansible playbooks  


###### 6. Executing Ansible Playbooks for PCD Host Onboarding  






