#!/usr/bin/env bash
#
# ------------------------------------------------------------------------------
# Name: deploy_ludus_lab.sh
# Description:
#   - Verifies that the Ludus CLI is installed; if not, exits with a link
#     to installation instructions.
#   - Based on a chosen scenario ("adcs-elastic" or "adcs-only"), checks
#     if the required Ansible roles are installed in Ludus; if not, installs them.
#   - Creates the deployment configuration file (lab_config.yml).
#   - Configures the range, deploys, and tails the logs.
#   - Includes error handling for the "ludus range config set" step.
#
# Usage:
#   ./deploy_ludus_lab.sh [scenario]
#
#   Where "scenario" can be:
#     - adcs-elastic (default)
#     - adcs-only
#
# Example:
#   ./deploy_ludus_lab.sh adcs-only
#
# Requirements:
#   - "ludus" must be installed and configured on the system so that
#     the following commands can be executed:
#         - ludus ansible roles list
#         - ludus ansible roles add
#         - ludus range config set
#         - ludus range deploy
#         - ludus range logs
#   - Make sure this script is executable:
#         chmod +x deploy_ludus_lab.sh
#
# ------------------------------------------------------------------------------
# Author: [Your Name/Alias]
# Date: [Creation Date]
# Versions:
#   - v1.0: Basic version with ADCS + Elastic
#   - v1.1: Added role verification using 'ludus ansible roles list'
#   - v1.2: Added error handling for 'ludus range config set'
#   - v1.3: Added verification to ensure 'ludus' is installed
#   - v1.4: Added ADCS-only scenario with parameterization
#
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Preliminary Check: Verify Ludus CLI is installed
# ------------------------------------------------------------------------------
if ! command -v ludus &> /dev/null; then
  echo "ERROR: 'ludus' CLI is not installed."
  echo "Refer to the official Ludus installation instructions here:"
  echo "  https://docs.ludus.cloud/docs/quick-start/install-ludus"
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 0: Determine the scenario (adcs-elastic or adcs-only) from the first argument
#         If not provided, default to adcs-elastic
# ------------------------------------------------------------------------------
# This way Elastic Security Agent is installed, so many local attacks will not work!!
# ------------------------------------------------------------------------------
SCENARIO="${1:-adcs-elastic}"
echo "Scenario chosen: $SCENARIO"

# ------------------------------------------------------------------------------
# Step 1: Check if required Ansible roles are installed in Ludus; if not, install them
#         We'll choose the roles depending on the scenario.
# ------------------------------------------------------------------------------
echo "Checking for required Ansible roles..."

if [[ "$SCENARIO" == "adcs-elastic" ]]; then
  REQUIRED_ROLES=(
    "badsectorlabs.ludus_adcs"
    "badsectorlabs.ludus_elastic_container"
    "badsectorlabs.ludus_elastic_agent"
  )
elif [[ "$SCENARIO" == "adcs-only" ]]; then
  REQUIRED_ROLES=(
    "badsectorlabs.ludus_adcs"
  )
else
  echo "ERROR: Unknown scenario '$SCENARIO'. Valid options are: adcs-elastic, adcs-only."
  exit 1
fi

# Retrieve the list of installed roles once to avoid multiple calls
INSTALLED_ROLES=$(ludus ansible roles list)

for ROLE in "${REQUIRED_ROLES[@]}"; do
  if echo "$INSTALLED_ROLES" | grep -q "$ROLE"; then
    echo "Role '$ROLE' is already installed."
  else
    echo "Installing role '$ROLE'..."
    ludus ansible roles add "$ROLE"
  fi
done

# ------------------------------------------------------------------------------
# Step 2: Create the YAML configuration file (lab_config.yml) with the
#         virtual machines definitions and network rules, based on the scenario.
# ------------------------------------------------------------------------------
echo "Creating 'lab_config.yml' configuration file for the '$SCENARIO' scenario..."

if [[ "$SCENARIO" == "adcs-elastic" ]]; then

cat > lab_config.yml << 'EOF'
ludus:
  - vm_name: "{{ range_id }}-elastic"
    hostname: "{{ range_id }}-elastic"
    template: debian-12-x64-server-template
    vlan: 20
    ip_last_octet: 1
    ram_gb: 8
    cpus: 4
    linux: true
    testing:
      snapshot: false
      block_internet: false
    roles:
      - name: badsectorlabs.ludus_elastic_container
    role_vars:
      ludus_elastic_password: "thisisapassword"

  - vm_name: "{{ range_id }}-ad-dc-win2022-server-x64"
    hostname: "{{ range_id }}-DC01-2022"
    template: win2022-server-x64-template
    vlan: 10
    ip_last_octet: 11
    ram_gb: 8
    cpus: 4
    windows:
      sysprep: false
    domain:
      fqdn: ludus.domain
      role: primary-dc
    roles:
      - name: badsectorlabs.ludus_adcs
      - name: badsectorlabs.ludus_elastic_agent
        depends_on:
          - vm_name: "{{ range_id }}-elastic"
            role: badsectorlabs.ludus_elastic_container

  - vm_name: "{{ range_id }}-ad-win11-22h2-enterprise-x64-1"
    hostname: "{{ range_id }}-WIN11-22H2-1"
    template: win11-22h2-x64-enterprise-template
    vlan: 10
    ip_last_octet: 21
    ram_gb: 8
    cpus: 4
    windows:
      install_additional_tools: true
      office_version: 2019
      office_arch: 64bit
    domain:
      fqdn: ludus.domain
      role: member
    roles:
      - name: badsectorlabs.ludus_elastic_agent
        depends_on:
          - vm_name: "{{ range_id }}-elastic"
            role: badsectorlabs.ludus_elastic_container

  - vm_name: "{{ range_id }}-kali"
    hostname: "{{ range_id }}-kali"
    template: kali-x64-desktop-template
    vlan: 99
    ip_last_octet: 1
    ram_gb: 8
    cpus: 4
    linux: true
    testing:
      snapshot: false
      block_internet: false

network:
  inter_vlan_default: REJECT
  rules:
    - name: Only allow windows to kali on 443
      vlan_src: 10
      vlan_dst: 99
      protocol: tcp
      ports: 443
      action: ACCEPT
    - name: Only allow windows to kali on 80
      vlan_src: 10
      vlan_dst: 99
      protocol: tcp
      ports: 80
      action: ACCEPT
    - name: Only allow windows to kali on 8080
      vlan_src: 10
      vlan_dst: 99
      protocol: tcp
      ports: 8080
      action: ACCEPT
    - name: Allow kali to all windows
      vlan_src: 99
      vlan_dst: 10
      protocol: all
      ports: all
      action: ACCEPT
EOF

else  # SCENARIO == "adcs-only"

cat > lab_config.yml << 'EOF'
ludus:
  - vm_name: "{{ range_id }}-ad-dc-win2022-server-x64"
    hostname: "{{ range_id }}-DC01-2022"
    template: win2022-server-x64-template
    vlan: 10
    ip_last_octet: 11
    ram_gb: 8
    cpus: 4
    windows:
      sysprep: false
    domain:
      fqdn: ludus.domain
      role: primary-dc
    roles:
      - name: badsectorlabs.ludus_adcs

  - vm_name: "{{ range_id }}-ad-win11-22h2-enterprise-x64-1"
    hostname: "{{ range_id }}-WIN11-22H2-1"
    template: win11-22h2-x64-enterprise-template
    vlan: 10
    ip_last_octet: 21
    ram_gb: 8
    cpus: 4
    windows:
      install_additional_tools: true
      office_version: 2019
      office_arch: 64bit
    domain:
      fqdn: ludus.domain
      role: member

  - vm_name: "{{ range_id }}-kali"
    hostname: "{{ range_id }}-kali"
    template: kali-x64-desktop-template
    vlan: 99
    ip_last_octet: 1
    ram_gb: 8
    cpus: 4
    linux: true
    testing:
      snapshot: false
      block_internet: false

network:
  inter_vlan_default: REJECT
  rules:
    - name: Allow Kali to all Windows machines
      vlan_src: 99
      vlan_dst: 10
      protocol: all
      ports: all
      action: ACCEPT
EOF

fi

# ------------------------------------------------------------------------------
# Step 3: Configure the range with the generated lab_config.yml (with error handling)
# ------------------------------------------------------------------------------
echo "Configuring the range using lab_config.yml for scenario '$SCENARIO'..."
if ! ludus range config set -f lab_config.yml; then
  echo "ERROR: Failed to configure the range. Exiting."
  exit 1
fi

# ------------------------------------------------------------------------------
# Step 4: Deploy the configuration
# ------------------------------------------------------------------------------
echo "Deploying the range for '$SCENARIO' scenario..."
ludus range deploy

# ------------------------------------------------------------------------------
# Step 5: Monitor deployment logs
# ------------------------------------------------------------------------------
echo "Monitoring the logs..."
ludus range logs -f

# End of script
echo "Deployment completed for scenario: $SCENARIO"
