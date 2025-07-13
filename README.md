# OpenShift 4 UPI KVM Automated Installation

[![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=flat&logo=ansible&logoColor=white)](https://www.ansible.com/)
[![OpenShift](https://img.shields.io/badge/OpenShift-EE0000?style=flat&logo=redhatopenshift&logoColor=white)](https://www.redhat.com/en/technologies/cloud-computing/openshift)
[![KVM](https://img.shields.io/badge/KVM-FF6600?style=flat&logo=qemu&logoColor=white)](https://www.linux-kvm.org/)

Automated OpenShift cluster deployment on KVM using Ansible. Supports both **Single Node OpenShift (SNO)** and **3-node clusters** with optional **OpenShift Data Foundation (ODF)** and **OpenShift Virtualization**.

## 🚀 Features

- ✅ **Single Node OpenShift (SNO)** deployment
- ✅ **3-node cluster** deployment  
- ✅ **OpenShift Data Foundation (ODF)** integration
- ✅ **OpenShift Virtualization** support
- ✅ **Modular Ansible structure** for better maintainability
- ✅ **Automated DNS/DHCP** configuration
- ✅ **HTPasswd authentication** setup
- ✅ **Day 2 operations** (add workers, storage)

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation Options](#installation-options)
- [Configuration](#configuration)
- [Usage](#usage)
- [Day 2 Operations](#day-2-operations)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## ⚠️ Important Notice

**Please exercise caution** when running this playbook, as it modifies network settings. Ensure you:
- Understand the changes being made
- Have appropriate backups or recovery plans
- Do not use in production

Running without careful review may lead to connectivity issues.

## 🖥️ Tested Environments

| Distribution | Status |
|-------------|--------|
| **Fedora 42** | ✅ Tested |
| **RHEL 8** | ✅ Tested |
| **RHEL 9** | ✅ Tested |

## 📦 Prerequisites

### System Requirements

- **User**: Non-root user with passwordless sudo access
- **Memory**: 32GB+ for SNO, 64GB+ for 3-node
- **Storage**: 200GB+ available disk space
- **Network**: Stable internet connection for downloads

### Required Software

#### 1. Install Ansible Core
```bash
sudo dnf install -y ansible-core
```

#### 2. Install Ansible Collections
```bash
ansible-galaxy collection install -r requirements.yml
```

#### 3. Generate SSH Key (if needed)
```bash
ssh-keygen -t rsa
```

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/lgchiaretto/ocp4_setup_upi_kvm_ansible.git
cd ocp4_setup_upi_kvm_ansible
```

### 2. Configure Variables
```bash
vim ansible-vars-kvm.yaml
```

### 3. Deploy Cluster

#### Option A: Using Modular Playbook (Recommended)
```bash
# Using helper script
./run-modular-playbook.sh

# Or directly
ansible-playbook -e @ansible-vars-kvm.yaml create-cluster-upi-kvm-modular.yaml
```

## 🛠️ Installation Options

### 🗂️ Modular Structure Benefits

```
roles/ocp_cluster/
├── defaults/main.yaml          # Centralized variables
└── tasks/
    ├── main.yaml              # Main orchestrator
    ├── validate.yaml          # Version validation
    ├── prerequisites.yaml     # System setup
    ├── download_resources.yaml # OCP downloads
    ├── create_vms.yaml        # VM creation
    ├── configure_network.yaml # DNS/DHCP setup
    ├── install_cluster.yaml   # Cluster installation
    └── ...                    # 20+ specialized tasks
```

**Benefits:**
- 🧩 **Modular**: Each function in dedicated file
- 🔧 **Maintainable**: Easy to debug and modify
- 🔄 **Reusable**: Role can be used in other projects
- 👥 **Collaborative**: Multiple developers can work simultaneously

## ⚙️ Configuration

### Variables Reference

Edit `ansible-vars-kvm.yaml` with your configuration. Get the pull secret from [Red Hat OpenShift Local](https://console.redhat.com/openshift/create/local).

#### Essential Variables

| Variable | Example | Description |
|----------|---------|-------------|
| `clustername` | `funny-flanders` | Cluster name (DNS-safe) |
| `basedomain` | `chiaret.to` | Base domain (**avoid .local**) |
| `ocpversion` | `4.16.16` | OpenShift version |
| `clusters_dir` | `"/labs"` | Directory for cluster files |
| `ssh_rsa` | `ssh-rsa AAAAB3Nza...` | SSH public key |
| `pullsecret` | `'{"auths":{"cloud.op...}}'` | Red Hat pull secret |

#### Cluster Type Configuration

| Variable | Options | Description |
|----------|---------|-------------|
| `sno` | `'true'` / `'false'` | Single Node vs 3-node cluster |
| `destroy_if_exists` | `'true'` / `'false'` | Clean existing cluster |

#### Resource Allocation

| Variable | SNO Example | 3-Node Example | Description |
|----------|-------------|----------------|-------------|
| `master_mem` | `'32000'` | `'16000'` | Master memory (MB) |
| `master_cpu` | `8` | `4` | Master CPU cores |
| `worker_mem` | `'4096'` | `'8192'` | Worker memory (MB) |
| `worker_cpu` | `4` | `4` | Worker CPU cores |
| `n_worker` | `0` | `2` | Number of workers |

#### Storage Configuration

| Variable | Example | Description |
|----------|---------|-------------|
| `extra_disks` | `0` / `3` | Extra disks per node |
| `extra_disk_size` | `100` | Extra disk size (GB) |
| `installodf` | `'false'` / `'true'` | Install ODF (3-node only) |
| `installocpvirt` | `'false'` / `'true'` | Install Virtualization |

#### Authentication

| Variable | Example | Description |
|----------|---------|-------------|
| `admin_user` | `"admin"` | HTPasswd username (empty to skip) |
| `htpasswd_pass` | `'Redhat@123'` | Admin password |
| `remove_kubeadmin_user` | `'true'` | Remove default kubeadmin |

#### Network Configuration

| Variable | Example | Description |
|----------|---------|-------------|
| `kvmnetwork` | `default` | KVM network name |
| `local_quay_registry` | `''` | Local registry URL (optional) |

### Configuration Examples

#### Single Node OpenShift (SNO)
```yaml
clustername: "sno-lab"
sno: 'true'
master_mem: '32000'
master_cpu: 8
n_worker: 0
installodf: 'false'
```

#### 3-Node with ODF
```yaml
clustername: "ocp-lab"
sno: 'false'
master_mem: '16000'
master_cpu: 4
n_worker: 0
extra_disks: 1
extra_disk_size: 100
installodf: 'true'
```

#### 3-Node with Workers
```yaml
clustername: "ocp-prod"
sno: 'false'
master_mem: '16000'
master_cpu: 4
n_worker: 3
worker_mem: '8192'
worker_cpu: 4
installodf: 'true'
installocpvirt: 'true'
```

## 🎯 Usage

### Create Cluster

```bash
# Edit configuration
vim ansible-vars-kvm.yaml

# Deploy using modular playbook (recommended)
./run-modular-playbook.sh

# Or deploy using original playbook
ansible-playbook -e @ansible-vars-kvm.yaml create-cluster-upi-kvm.yaml
```

### Access Cluster

```bash
# Set kubeconfig
export KUBECONFIG="/labs/your-cluster/auth/kubeconfig"

# Verify cluster
oc get nodes
oc get clusterversion
```

### Login to Web Console

```bash
# Get console URL
oc whoami --show-console

# Get admin password (if configured)
echo "Username: admin"
echo "Password: $(grep htpasswd_pass ansible-vars-kvm.yaml | cut -d: -f2 | tr -d "' ")"
```

## 🔄 Day 2 Operations

### Add Worker Nodes

Expand your cluster by adding worker nodes after initial deployment.

```bash
# Edit variables to increase worker count
vim ansible-vars-kvm.yaml  # Modify n_worker value

# Deploy additional workers
ansible-playbook -e @ansible-vars-kvm.yaml add-new-nodes.yaml
```

### Configure LVM Storage

Set up Logical Volume Manager (LVM) storage using the LVM Operator.

#### Prerequisites
- Cluster with at least 1 extra disk (`extra_disks >= 1`)
- Properly configured `ansible-vars-kvm.yaml`

#### Deployment
```bash
ansible-playbook -e @ansible-vars-kvm.yaml d2-lvm-storage.yaml
```

#### What it does:
- ✅ Creates `openshift-storage` namespace
- ✅ Installs LVM Operator from OperatorHub
- ✅ Configures LVMCluster resource
- ✅ Creates test PVC and Pod for verification
- ✅ Automatically detects available disks (`vdb`, `vdc`, etc.)

### Cluster Cleanup

Remove an existing cluster completely:

```bash
# Set destroy flag and re-run
ansible-playbook -e @ansible-vars-kvm.yaml -e destroy_if_exists=true create-cluster-upi-kvm-modular.yaml --tags cleanup
```

## 🔧 Troubleshooting

### Common Issues

#### 1. OpenShift Installation Failures
```bash
# Monitor installation progress
export KUBECONFIG="/labs/your-cluster/auth/kubeconfig"
oc get clusteroperators
oc get nodes

# Check installer logs
tail -f /labs/your-cluster/.openshift_install.log
```

### Debug Mode

Run with verbose output for troubleshooting:

```bash
# Verbose mode
ansible-playbook -vvv -e @ansible-vars-kvm.yaml create-cluster-upi-kvm-modular.yaml
```

