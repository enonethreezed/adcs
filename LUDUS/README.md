# Ludus Lab Deployment Script

This repository contains a Bash script to deploy two possible lab scenarios using the **Ludus CLI**:

- **ADCS + Elastic** (default)
- **ADCS-only**

---

## Prerequisites

1. **Ludus CLI**  
   Make sure [Ludus](https://docs.ludus.cloud/docs/quick-start/install-ludus) is installed and configured on your system.  
   The script checks for Ludus automatically, and if it’s not found, it will exit with an installation reference link.

2. **Ansible Roles**  
   - `badsectorlabs.ludus_adcs`  
   - `badsectorlabs.ludus_elastic_container` (required for ADCS + Elastic)  
   - `badsectorlabs.ludus_elastic_agent` (required for ADCS + Elastic)

   The script verifies if these roles are installed using `ludus ansible roles list`.  
   If any are missing, it will install them automatically.

---

## Usage

```bash
./deploy_ludus_lab.sh [scenario]
