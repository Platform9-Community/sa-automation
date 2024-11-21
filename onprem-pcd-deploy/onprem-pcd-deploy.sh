#!/bin/bash

# Function to print prerequisites and instructions
print_instructions() {
echo -e "
Welcome to the On-Prem Private Cloud Director(PCD) deployment, we need few details from user and few prerequisites in place before we proceed. Please go through below points to confirm the required details are handy and prerequisites are met.

1. Minimum 3 nodes acting as Nodelet cluster's master nodes with at least following specifications - 6 CPU, 9.8 GB RAM and 160 GB disk Size. Keep the IPs of all the nodes handy.

2. Optionally any number of worker nodes and their IPs.

3. This automation needs to be executed from a master node acting as primary node for deployment and from that node password less ssh with 'ubuntu' or 'rocky' user(as per host OS) to all other nodes should already be in place OR user needs to provide password to the automation script during execution.

4. 'USER AGENT KEY' to download artificats from Platform9's AWS S3. Get it from the Platform9 representative if not present.

5. Primary interface name like ens3 or eth0 or bond0 that would be consistent across all the cluster nodes.

6. Need a VIP for multi master management cluster's kube-apiserver which should be on the same subnet as that of node's primary interface.

7. We need one external IP to which the PCD's management plane(DU) FQDN will get resolve to. This should also be of the same L2 subnet as that of node's primary interface IP.

8. At least 1 DU region name, if not specified, 'RegionOne' will be default.

9. We need to specify one base Infra region DU FQDN and region specific FQDNs based on number of regions you specify. The region specific FQDN is the URL at which user would be accessing the PCD management plane. The external IP that you specify gets resolv to the region specific FQDNs.

10. If DU needs to be behind proxy then keep values of following parameters handy: 'https_proxy', 'http_proxy' and 'no_proxy'. As per PCD's requirement few IPs and FQDNs will be auto added to 'no_proxy'.


=--> If ALL the above details are available and prerequisites are met, then press 'y' to continue, else press 'n' to come back later with details.
\n"
}

# Prompt for user decision
print_instructions
read -p "Do you want to proceed? (y/n): " proceed
echo -e "\n"

if [[ "$proceed" != "y" && "$proceed" != "Y" ]]; then
  echo "Exiting..."
  exit 0
fi

# Function to validate IPs
validate_ips() {
  local ip_list=($1)
  for ip in "${ip_list[@]}"; do
    if ! [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "   Error: Invalid IP address: $ip"
      return 1
    fi
  done
  return 0
}

# Collect inputs
while true; do
  read -p "> Enter the number of master nodes (1/3/5): " num_masters
  if [[ -z "$num_masters" ]]; then
    echo -e "   Error: null input"
    continue
  fi
  val=$(($num_masters % 2))
  if ! [[ "$val" -eq 0 ]]; then
    break
  else
    echo -e "   Error: You must enter odd number of master nodes."
  fi
done

while true; do
  read -p "> Enter the IPs of master nodes separated by spaces: " -a master_ips
  if [[ "${#master_ips[@]}" -eq "$num_masters" ]]; then
    validate_ips "${master_ips[*]}" && break
  else
    echo -e "   Error: You must enter exactly $num_masters valid IP address(es)."
  fi
done

read -p "> Number of worker nodes (optional, press enter to skip): " num_workers
num_workers=${num_workers:-0}

if [[ "$num_workers" -gt 0 ]]; then
  while true; do
    read -p "> Enter the IPs of worker nodes separated by spaces: " -a worker_ips
    if [[ "${#worker_ips[@]}" -eq "$num_workers" ]]; then
      validate_ips "${worker_ips[*]}" && break
    else
      echo "   Error: You must enter exactly $num_workers valid IP addresses."
    fi
  done
else
  worker_ips=()
fi

while true; do
  read -p "> Is passwordless SSH access from this node to all the other nodes present (y/n)? " ssh_access
  if [[ "$ssh_access" =~ ^[yY](es)?$ ]]; then
    ssh_password=""
    break
  elif [[ "$ssh_access" =~ ^[nN](o)?$ ]]; then
    read -s -p "> Enter password for 'ubuntu'/'rocky' user: " ssh_password
    echo
    break
  else
    echo "   Error: Please enter 'y' or 'n'."
  fi
done

read -p "> Enter USER-AGENT-KEY: " user_agent_key

while true; do
read -p "> Enter kube-apiserver VIP for management cluster: " management_vip
    if [ -n "$management_vip" ]; then
      validate_ips "$management_vip" && break
    else
      echo "   Error: You must enter exactly 1 valid VIP addresses."
    fi
done

while true; do
read -p "> Enter external IP for DU: " external_ip
    if [ -n "$external_ip" ]; then
      validate_ips "$external_ip" && break
    else
      echo "   Error: You must enter exactly 1 valid VIP addresses."
    fi
done

read -p "> Enter primary interface name: " primary_interface
read -p "> Enter Infra region management plane FQDN: " du_infra_fqdn

read -p "> Enter DU regions separated by spaces ('RegionOne' default): " -a du_regions
  if [[ ${#du_regions[@]} -eq 0 ]]; then
    du_regions=RegionOne
  fi

domain_suffix=$(echo "$du_infra_fqdn" | awk -F. '{print $(NF-1)"."$NF}')

while true; do
  read -p "> Enter ${#du_regions[@]} new FQDN(s), one for each region (must be subdomains of $du_infra_fqdn): " -a du_region_fqdn

  # Check if the correct number of FQDNs were entered
  if [[ ${#du_region_fqdn[@]} -ne ${#du_regions[@]} ]]; then
    echo "   Error: You must enter ${#du_regions[@]} FQDN(s), equal to the number of entered regions."
    continue
  fi

  # Validate each new FQDN
  invalid_fqdn=false
  fqdn_set=()
  for fqdn in "${du_region_fqdn[@]}"; do
    if [[ ! "$fqdn" == *".$domain_suffix" ]]; then
      echo "   Error: FQDN '$fqdn' is not a subdomain of $du_infra_fqdn."
      invalid_fqdn=true
      break
    fi

  if [[ " ${fqdn_set[*]} " =~ " $fqdn " ]]; then
    echo "   Error: Duplicate FQDN '$fqdn' detected. Each FQDN must be unique."
    invalid_fqdn=true
    break
  fi

  # Add FQDN to the tracking array
  fqdn_set+=("$fqdn")

  done

  # If all validations pass, break the loop
  if [[ "$invalid_fqdn" == false ]]; then
    break
  fi

done

read -p "> Do you want to use a proxy? (y/n): " use_proxy
if [[ "$use_proxy" =~ ^[yY](es)?$ ]]; then
  read -p "  Enter https_proxy ("http://squid.abc.com:3128"): " https_proxy
  read -p "  Enter http_proxy ("http://squid.abc.com:3128"): " http_proxy
  read -p "  Enter no_proxy: ("ip1,ip2,.domain1,domain2"): " no_proxy

  extra_no_proxy="127.0.0.1,localhost,::1,.svc,.svc.cluster.local,10.21.0.0/16,10.20.0.0/16,.cluster.local,.default.svc"
  
  # Add all master and worker IPs, management FQDN, and external IP
  extra_no_proxy+=",${master_ips[*]}"
  [[ -n "${worker_ips[*]}" ]] && extra_no_proxy+=",${worker_ips[*]}"
  extra_no_proxy+=",${du_infra_fqdn},${du_region_fqdn[*]},${external_ip},${management_vip}"
  
  # Ensure comma-separated list format
  extra_no_proxy=$(echo "$extra_no_proxy" | tr ' ' ',')

  # Combine user input with additional values
  if [[ -n "$no_proxy" ]]; then
    no_proxy="${no_proxy},${extra_no_proxy}"
  else
    no_proxy="${extra_no_proxy}"
  fi

else
  https_proxy=""
  http_proxy=""
  no_proxy=""
fi

# Summary of inputs
echo -e "\n\n===== Summary of Inputs =====\n"
echo "Number of master nodes: $num_masters"
echo "Master node IPs: ${master_ips[*]}"
echo "Number of worker nodes: $num_workers"
echo "Worker node IPs: ${worker_ips[*]}"
echo "Passwordless SSH: $ssh_access"
if [[ -n "$ssh_password" ]]; then
  echo "Password for 'ubuntu'/'rocky': ******"
fi
echo "USER-AGENT-KEY: $user_agent_key"
echo "kube-apiserver VIP for management cluster: $management_vip"
echo "External IP for DU: $external_ip"
echo "Primary Interface: $primary_interface"
echo "Infra region management plane FQDN: $du_infra_fqdn"
echo "Region specific management plane FQDNs: ${du_region_fqdn[*]}"
echo "DU regions: ${du_regions[*]}"
if [[ -n "$https_proxy" || -n "$http_proxy" || -n "$no_proxy" ]]; then
  echo "Proxy settings:"
  echo "  https_proxy: $https_proxy"
  echo "  http_proxy: $http_proxy"
  echo "  no_proxy: $no_proxy"
else
  echo "Proxy settings: Not configured"
fi
echo -e "\n=============================="

# Save all inputs to a text file
output_file="user_inputs.txt"
> "$output_file"
{
echo -e "\n===== User Inputs =====\n" 
echo "Number of master nodes: $num_masters"
echo "Master node IPs: ${master_ips[*]}"
echo "Number of worker nodes: $num_workers"
echo "Worker node IPs: ${worker_ips[*]}"
echo "Passwordless SSH: $ssh_access"
if [[ -n "$ssh_password" ]]; then
  echo "Password for 'ubuntu'/'rocky' user: ****** (hidden)"
fi
echo "USER-AGENT-KEY: $user_agent_key"
echo "kube-apiserver VIP for management cluster: $management_vip"
echo "External IP for DU: $external_ip"
echo "Primary Interface: $primary_interface"
echo "Infra region management plane FQDN: $du_infra_fqdn"
echo "DU regions: ${du_regions[*]}"
echo "Region specific management plane FQDNs: ${du_region_fqdn[*]}"
if [[ -n "$https_proxy" || -n "$http_proxy" || -n "$no_proxy" ]]; then
  echo "Proxy settings:"
  echo "  https_proxy: $https_proxy"
  echo "  http_proxy: $http_proxy"
  echo "  no_proxy: $no_proxy"
else
  echo "Proxy settings: Not configured"
fi
echo -e "\n=============================="
} > "$output_file"

echo -e "\nAll details saved to $output_file."

echo -e "\nUpdating system and installing prerequisite packages."
sudo apt-get update -y && sudo apt-get install cgroup-tools -y

sudo curl --user-agent "$user_agent_key" https://pf9-airctl.s3-accelerate.amazonaws.com/openssl-smcp-ubuntu/openssl_3.0.7-1_amd64.deb --output openssl_3.0.7-1_amd64.deb
sudo dpkg -i openssl_3.0.7-1_amd64.deb
sudo cd /etc/ld.so.conf.d/
sudo echo "/usr/local/ssl/lib64" > openssl-3.0.7.conf
sudo ldconfig -v
sudo sed -i 's/\(^PATH="[^"]*\)"/\1:\/usr\/local\/ssl\/bin"/' /etc/environment
sudo source /etc/environment
sudo ln -sf /usr/local/ssl/bin/openssl /usr/bin/openssl
sudo openssl version

echo -e "\nDownloading and extracting artificats from AWS S3."
sudo curl --user-agent "$user_agent_key" https://pf9-airctl.s3-accelerate.amazonaws.com/latest/index.txt | grep -e airctl -e install-pcd.sh -e nodelet-deb.tar.gz -e nodelet.tar.gz -e pcd-chart.tgz -e options.json -e version.txt | awk '{print "curl -sS --user-agent \"$user_agent_key\" \"https://pf9-airctl.s3-accelerate.amazonaws.com/latest/" $NF "\" -o /root/" $NF}' | bash
sudo chmod +x ./install-pcd.sh
./install-pcd.sh `cat version.txt`
sudo cp /opt/pf9/airctl /usr/bin/

echo -e "\n 'airctl configure' command execuation starts here..., currently waiting for fix! PR https://github.com/platform9/airctl/pull/1066"
## airctl configure .... waiting for the fix



