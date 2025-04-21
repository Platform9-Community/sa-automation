import csv
import subprocess
import json
import time
import argparse
from string import Template
import os
from concurrent.futures import ThreadPoolExecutor
from jinja2 import Environment, FileSystemLoader
import logging

###############################################################################
#                           Argument parsing                                  #
###############################################################################
parser = argparse.ArgumentParser(description="Add and deploy MAAS machines from a CSV file.and PCD Node Onboarding")
parser.add_argument("-maas_user","--maas_user", required=True, help="MAAS username")
parser.add_argument("-csv_filename","--csv_filename", required=True, help="CSV file path")
parser.add_argument("-cloud_init_template", "--cloud_init_template", required=True, help="Cloud-init template YAML path ")
parser.add_argument("-portal", "--portal", required=True, help="Region name (REQUIRED)")
parser.add_argument("-region", "--region", required=True, help="Site name to form DU=<portal>-<region> (REQUIRED)")
parser.add_argument("-environment", "--environment", required=True, help="Environment name to segregate hosts")
parser.add_argument("-url", "--url", required=True, help="Portal URL for blueprint/hostconfigs/network resources")
parser.add_argument("-setup-environment", "--setup-environment", required=True, help="Set up Ansible environment: yes|no")
parser.add_argument("-ssh_user", "--ssh_user", required=True, help="SSH user for Ansible")
args = parser.parse_args()

maas_user = args.maas_user
csv_file = args.csv_filename
cloud_init_template = args.cloud_init_template


###############################################################################
#                              configure logging                              #
###############################################################################
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("maas_deploy.log"),
        logging.StreamHandler()
    ]
)

###############################################################################
#                                   Load CSV                                  #
###############################################################################
try:
    with open(csv_file, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        rows = list(reader)  # Use this wherever you need
except Exception as e:
    logging.error(f"Error reading CSV:{e.returncode}")
    logging.error(f"STDERR: {e.stderr.strip()}")
    logging.error(f"STDOUT: {e.stdout.strip()}")
    exit(1)

###############################################################################
#                        LogIn to MAAS Admin Profile                          #
###############################################################################


###############################################################################
#               creating and deploying machines in MAAS                       #
###############################################################################
def get_machine_status(maas_user, system_id):
    result = subprocess.run(["maas", maas_user, "machine", "read", system_id], capture_output=True, text=True)
    if result.returncode == 0:
        machine_info = json.loads(result.stdout)
        return machine_info.get("status_name", "Unknown")
    return "Unknown"

def wait_for_status(maas_user, system_id, expected_status, hostname, timeout=600, interval=30):
    elapsed = 0

    while elapsed < timeout:
        status = get_machine_status(maas_user, system_id)
        logging.info(f"[{hostname}] Status: {status}")
        if status == expected_status:
            logging.info(f"[{hostname}] Start Deploying OS")
            return True
        time.sleep(interval)
        elapsed += interval
    logging.info(f"[{hostname}] Timeout waiting for status: {expected_status}")
    return False

def generate_cloud_init(template_file, output_file, ip):
    with open(template_file, 'r') as f:
        template = Template(f.read())
    rendered = template.safe_substitute(ip=ip)
    with open(output_file, 'w') as f:
        f.write(rendered)

def create_machine(maas_user, row):
    hostname = row["hostname"]
    architecture = row["architecture"]
    mac_addresses = row["mac_addresses"]
    power_type = row["power_type"]

    power_parameters = {
        "power_user": row["power_user"],
        "power_pass": row["power_pass"],
        "power_driver": row["power_driver"],
        "power_address": row["power_address"],
        "cipher_suite_id": row["cipher_suite_id"],
        "power_boot_type": row["power_boot_type"],
        "privilege_level": row["privilege_level"],
        "k_g": row["k_g"]
    }

    create_command = [
        "maas", maas_user, "machines", "create",
        f"hostname={hostname}",
        f"architecture={architecture}",
        f"mac_addresses={mac_addresses}",
        f"power_type={power_type}",
        f"power_parameters={json.dumps(power_parameters)}"
    ]

    try:
        result = subprocess.run(create_command, check=True, capture_output=True, text=True)
        logging.info(f"[{hostname}] Machine created.")
        response = json.loads(result.stdout)
        return hostname, response.get("system_id"), row
    except subprocess.CalledProcessError as e:
        logging.error(f"[{hostname}] Error creating machine:{e.returncode}")
        logging.error(f"STDERR: {e.stderr.strip()}")
        logging.error(f"STDOUT: {e.stdout.strip()}")
        return hostname, None, row

def configure_and_deploy(maas_user, hostname, system_id, row, cloud_init_template):
    if not system_id:
        logging.info(f"[{hostname}] Skipping: no system_id.")
        row["deployment_status"] = "System ID Missing Machine Was Not Created"
        return

    if wait_for_status(maas_user, system_id, "Ready", hostname, 600, 30):
        temp_cloud_init = f"/tmp/cloud-init-{hostname}.yaml"
        generate_cloud_init(cloud_init_template, temp_cloud_init, row["ip"])
        try:
            deploy_command = f'maas {maas_user} machine deploy {system_id} user_data="$(base64 -w 0 {temp_cloud_init})"'
            logging.info(f"[{hostname}] Deploy triggered with cloud-init.")
            subprocess.run(deploy_command, shell=True, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            logging.error(f"[{hostname}] Deploy failed:{e.returncode}")
            logging.error(f"STDERR: {e.stderr.strip()}")
            logging.error(f"STDOUT: {e.stdout.strip()}")
            row["deployment_status"] = "Deploy Failed"
            os.remove(temp_cloud_init)
            return

        if wait_for_status(maas_user, system_id, "Deployed", hostname, 1200, 60):
            logging.info(f"[{hostname}] Deployment completed.")
            update_ipmi_user(system_id, hostname, row)
            row["deployment_status"] = "Deployed"
        else:
            logging.info(f"[{hostname}] Did not reach Deployed state.")
            row["deployment_status"] = "Deployment Timeout"

        os.remove(temp_cloud_init)
    else:
        logging.info(f"[{hostname}] Not Ready. Skipping deployment.")
        row["deployment_status"] = "Not Ready,Commissioning Was Not Done"

def update_ipmi_user(system_id, hostname, row):
    """Replace the default 'maas' user in IPMI settings after deployment."""
    power_params = json.dumps({
        "power_user": row["power_user"],
        "power_pass": row["power_pass"]
    })
   
    update_command = [
        "maas", "admin", "machine", "update", system_id,
        f"power_parameters={power_params}"
    ]
    try:
        subprocess.run(update_command, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        print(f"Failed to update IPMI user for {hostname}: {str(e)}")
        

# Create machines
with ThreadPoolExecutor(max_workers=5) as executor:
    futures = [executor.submit(create_machine, maas_user, row) for row in rows]
    results = [f.result() for f in futures]

# Deploy machines
with ThreadPoolExecutor(max_workers=5) as executor:
    executor.map(lambda args: configure_and_deploy(maas_user, *args, cloud_init_template), results)

###############################################################################
#                           Add status to CSV file                            #
###############################################################################

fieldnames = list(rows[0].keys())
if "deployment_status" not in fieldnames:
    fieldnames.append("deployment_status")

# Write back the rows with deployment status
try:
    with open(csv_file, "w", newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    logging.info(f"Updated CSV with deployment status at {csv_file}")
except Exception as e:
    logging.error(f"Error writing to CSV:{e.returncode}")
    logging.error(f"STDERR: {e.stderr.strip()}")
    logging.error(f"STDOUT: {e.stdout.strip()}")


###############################################################################
#                           Setup paths and context                           #
###############################################################################
current_dir = os.path.dirname(os.path.abspath(__file__))
home = os.getenv("HOME")
output_file = os.path.join(current_dir, "vars.yaml")
template_file = os.path.join(current_dir, "vars_template.j2")
pcd_dir = os.path.join(current_dir, "pcd_ansible-pcd_develop")

###############################################################################
#                                   ReLoad CSV                                #
###############################################################################
try:
    with open(csv_file, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        rows = list(reader)  # Use this wherever you need
except Exception as e:
    logging.error(f"Error reading CSV:{e}")
    exit(1)

###############################################################################
#                                build hosts dict                            #
###############################################################################
hosts = {}
for row in rows:
    ip = row.get("ip")
    status= row.get("deployment_status")
    if ip and status=="Deployed":
        hosts[ip] = {
            "ansible_ssh_user": args.ssh_user,
            "ansible_ssh_private_key_file": f"{home}/.ssh/id_rsa",
            "roles": ["node_onboard"]
        }
if not hosts:
    logging.info("No hosts to onboard.")
    exit(0)

###############################################################################
#                           Render vars.yml using Jinja2                      #
###############################################################################
env = Environment(loader=FileSystemLoader(current_dir))
template = env.get_template("vars_template.j2")

yaml_content = template.render(
    url=args.url,
    cloud=args.region,
    environment=args.environment,
    hosts=hosts
)

try:
    with open(output_file, "w") as f:
        f.write(yaml_content)
    logging.info(f"Generated '{output_file}' successfully!")
except Exception as e:
    logging.error(f"Error writing vars.yaml: {e}")
    exit(1)

###############################################################################
#                           Run onboarding via PCD Ansible                    #
###############################################################################
try:
    os.chdir(pcd_dir)

    subprocess.run(["cp", "-f", output_file, "user_resource_examples/templates/host_onboard_data.yaml.j2"], check=True)

    subprocess.run([
        "./pcdExpress",
        "-portal", args.portal,
        "-region", args.region,
        "-env", args.environment,
        "-url", args.url,
        "-ostype", "ubuntu",
        "-setup-environment", args.setup_environment
    ], check=True)

    subprocess.run([
        "./pcdExpress",
        "-env-file", f"user_configs/{args.portal}/{args.region}/{args.portal}-{args.region}-{args.environment}-environment.yaml",
        "-render-userconfig", f"user_configs/{args.portal}/{args.region}/node-onboarding/{args.portal}-{args.region}-nodesdata.yaml"
    ], check=True)

    subprocess.run([
        "./pcdExpress",
        "-env-file", f"user_configs/{args.portal}/{args.region}/{args.portal}-{args.region}-{args.environment}-environment.yaml",
        "-create-hostagents-configs", "yes"
    ], check=True)

    subprocess.run([
        "./pcdExpress",
        "-env-file", f"user_configs/{args.portal}/{args.region}/{args.portal}-{args.region}-{args.environment}-environment.yaml",
        "-apply-hosts-onboard", "yes"
    ], check=True)

except subprocess.CalledProcessError as e:
    print(f"Error during subprocess execution: {e}")
    exit(1)       
