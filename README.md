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
- ✅ **LVM Storage** for lightweight persistent storage
- ✅ **Modular Ansible structure** for better maintainability
- ✅ **Automated DNS/DHCP** configuration
- ✅ **HTPasswd authentication** setup
- ✅ **Day 2 operations** (add workers, storage)
- ✅ **VM management scripts** (start/stop)

## 📋 Table of Contents

- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Configuration](#️-configuration)
- [Usage](#-usage)
- [Day 2 Operations](#-day-2-operations)
- [Troubleshooting](#-troubleshooting)

## 🏗️ Architecture

### Deployment Flow

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Validate   │───▶│ Prerequisites│───▶│   Cleanup   │
└─────────────┘     └──────────────┘     └─────────────┘
                                              │
        ┌─────────────────────────────────────┘
        ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Download   │───▶│   Prepare    │───▶│ Create VMs  │
└─────────────┘     └──────────────┘     └─────────────┘
                                              │
        ┌─────────────────────────────────────┘
        ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Configure  │───▶│   Workers    │───▶│   Install   │
│   Network   │     │  (optional)  │     │   Cluster   │
└─────────────┘     └──────────────┘     └─────────────┘
                                              │
        ┌─────────────────────────────────────┘
        ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│    Auth     │───▶│   Storage    │───▶│    Virt     │
│  (optional) │     │  (optional)  │     │  (optional) │
└─────────────┘     └──────────────┘     └─────────────┘
```

### SNO vs 3-Node Cluster

| Feature | SNO | 3-Node |
|---------|-----|--------|
| Masters | 1 | 3 |
| Workers | 0 | 0+ |
| Load Balancer | No | Yes (HAProxy) |
| ODF Support | No | Yes |
| Min Memory | 32GB | 48GB+ |
| Ignition | Embedded in ISO | HTTP served |

### Directory Structure

```
clusters_dir/
├── .cache/                    # Cached downloads by OCP version
│   └── 4.16/
│       ├── openshift-install-linux-4.16.16.tar.gz
│       ├── rhcos.iso
│       └── ...
└── <clustername>/            # Cluster-specific files
    ├── auth/
    │   ├── kubeconfig
    │   └── kubeadmin-password
    ├── *.qcow2               # VM disks
    ├── *.ign                 # Ignition configs
    ├── startvms.sh           # Start all VMs
    └── stopvms.sh            # Stop all VMs
```

## ⚠️ Important Notice

**Please exercise caution** when running this playbook, as it modifies network settings. Ensure you:
- Understand the changes being made
- Have appropriate backups or recovery plans
- Do not use in production

Running without careful review may lead to connectivity issues.

## 🖥️ Tested Environments

| Distribution | Status |
|-------------|--------|
| **Fedora 42+** | ✅ Tested |
| **RHEL 8** | ✅ Tested |
| **RHEL 9** | ✅ Tested |

## 📦 Prerequisites

### System Requirements

| Requirement | SNO | 3-Node | 3-Node + Workers |
|-------------|-----|--------|------------------|
| **Memory** | 32GB+ | 48GB+ | 64GB+ |
| **Storage** | 200GB+ | 400GB+ | 600GB+ |
| **CPU Cores** | 8+ | 12+ | 16+ |

- **User**: Non-root user with passwordless sudo access
- **Network**: Stable internet connection for downloads

### Required Software

#### 1. Install Ansible Core
```bash
sudo dnf install -y ansible-core
```

#### 2. Generate SSH Key (if needed)
```bash
ssh-keygen -t rsa -N ""
```

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/lgchiaretto/ocp4_setup_upi_kvm_ansible.git
cd ocp4_setup_upi_kvm_ansible
```

### 2. Install Ansible Collections
```bash
ansible-galaxy collection install -r requirements.yml
```

### 3. Configure Variables
```bash
cp ansible-vars-kvm.yaml my-cluster.yaml
vim my-cluster.yaml
```

### 4. Deploy Cluster

```bash
# Using helper script
./run-modular-playbook.sh -v my-cluster.yaml

# Or directly
ansible-playbook -e @my-cluster.yaml create-cluster-upi-kvm-modular.yaml
```

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
| `extra_disks` | `0` / `3` | Extra disks per node (max 10) |
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
extra_disks: 1         # For LVM storage
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

#### 3-Node with Workers and OCP Virtualization
```yaml
clustername: "ocp-prod"
sno: 'false'
master_mem: '16000'
master_cpu: 4
n_worker: 3
worker_mem: '8192'
worker_cpu: 4
extra_disks: 1
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
ansible-playbook -e @ansible-vars-kvm.yaml create-cluster-upi-kvm-modular.yaml
```

### Access Cluster

```bash
# Set kubeconfig
export KUBECONFIG="/labs/your-cluster/auth/kubeconfig"

# Verify cluster
oc get nodes
oc get clusterversion
oc get clusteroperators
```

### Manage VMs

```bash
cd /labs/your-cluster

# Start all VMs
./startvms.sh

# Stop gracefully
./stopvms.sh

# Force stop
./stopvms.sh force
```

### Destroy Cluster

```bash
ansible-playbook -e @ansible-vars-kvm.yaml destroy-cluster.yml
```

## 🔄 Day 2 Operations

### Add Worker Nodes

Expand your cluster by adding worker nodes after initial deployment.

```bash
# Edit variables to increase worker count
vim ansible-vars-kvm.yaml  # Set n_worker to desired count

# Deploy additional workers
ansible-playbook -e @ansible-vars-kvm.yaml add-new-nodes.yaml
```

### Configure LVM Storage

Set up Logical Volume Manager (LVM) storage using the LVM Operator. Ideal for SNO clusters or when ODF is not needed.

#### Prerequisites
- Cluster with at least 1 extra disk (`extra_disks >= 1`)

#### Deployment
```bash
ansible-playbook -e @ansible-vars-kvm.yaml d2-lvm-storage.yaml
```

#### What it does:
- ✅ Creates `openshift-storage` namespace
- ✅ Installs LVM Operator from OperatorHub
- ✅ Configures LVMCluster with available disks
- ✅ Creates `lvms-vg1` StorageClass
- ✅ Runs validation test with PVC/Pod

### Configure Object Storage (MCG)

Set up Multi-Cloud Gateway for S3-compatible object storage.

```bash
ansible-playbook -e @ansible-vars-kvm.yaml d2-objectstorage.yaml
```

## 🔧 Troubleshooting

### Common Issues

#### 1. OCP Version Not Found
```
TASK [Validate OCP version] ***************************************************
fatal: [localhost]: FAILED! => {"msg": "Invalid OCP version: '4.99.0'"}
```
**Solution**: Check available versions at https://mirror.openshift.com/pub/openshift-v4/clients/ocp/

#### 2. DNS Resolution Issues
```
error: dial tcp: lookup api.cluster.domain.com: no such host
```
**Solution**: 
- Verify NetworkManager is using dnsmasq
- Check `/etc/NetworkManager/dnsmasq.d/<clustername>.conf`
- Avoid using `.local` domain

#### 3. VM Creation Fails
```
ERROR: Cannot allocate memory
```
**Solution**: 
- Reduce `master_mem` or `worker_mem`
- Close other applications
- Check available memory: `free -h`

#### 4. Bootstrap Never Completes
```
TASK [Check if bootstrap can be removed] **************************************
FAILED - RETRYING: Check if bootstrap...
```
**Solution**:
- Monitor logs: `tail -f /labs/cluster/.openshift_install.log`
- Check bootstrap console: `virsh console cluster-bootstrap`
- Verify ignition was served correctly

### Debug Commands

```bash
# Check cluster operators
oc get clusteroperators

# Check node status
oc get nodes -o wide

# Check pending CSRs
oc get csr | grep Pending

# Approve pending CSRs
oc get csr -o name | xargs oc adm certificate approve

# Check pod status
oc get pods -A | grep -v Running | grep -v Completed

# Monitor installation
tail -f /labs/cluster/.openshift_install.log
```

### Verbose Mode

Run with verbose output for troubleshooting:

```bash
ansible-playbook -vvv -e @ansible-vars-kvm.yaml create-cluster-upi-kvm-modular.yaml
```