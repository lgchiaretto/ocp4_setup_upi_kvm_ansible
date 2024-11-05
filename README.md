# OpenShift 4 Automated Cluster Installation (UPI on KVM) using Ansible

This automation helps you create a Single Node OpenShift (SNO) or 3-node cluster on a KVM host using Libvirt. It's possible to configure OpenShift Data Foundation (ODF) and OpenShift Virtualization when 3-node cluster.

## ⚠️ Important Notice

Please be sure to exercise caution when running this playbook, as the initial tasks modify network settings. Ensure that you fully understand the changes being made and have appropriate backups or recovery plans in place before proceeding. Running these tasks without careful review may lead to connectivity issues or unintended network configuration changes.

## Tested Environments

This playbook has been successfully tested on the following distributions:

    Fedora 40
    RHEL 8
    RHEL 9

Please make sure that your environment meets these system requirements for the best results.

# Prerequisites

## User

You must run this playbook with sudo passwordless ( do not use 'root' user)

## Install Ansible Core

To install ansible-core, run the following command:

```
sudo dnf install -y ansible-core
```


## Generate an SSH Key

If you don't already have an SSH key, generate one using:

```
ssh-keygen -t rsa
```

## Edit Ansible Variables

Before running the playbook, edit the Ansible variables file and fill in the required parameters, such as sshrsa and pullsecret. You can obtain the pull secret by accessing Red Hat OpenShift Local (https://console.redhat.com/openshift/create/local) and clicking "Download pull secret".


| Variable             | Value (Example)              | Description                                                                                 |
|-----------------------|---------------------|---------------------------------------------------------------------------------------------|
| `clustername` | funny-flanders | The name of the cluster |
| `basedomain` | chiaret.to | Base domain of the cluster (do not use .local) |
| `ocpversion` | 4.16.16 | OpenShift version |
| `clusters_dir` | "/labs" | Directory to create cluster files |
| `sno` | 'true' | Defines the type of cluster to create. Use `'true'` for Single Node OpenShift and `'false'` for a 3-node cluster. |
| `destroy_if_exists` | `'true'` or `'false'` | Removes the existing cluster before creating a new one. |
| `kvmnetwork` | default | Network configured on KVM |
| `worker_mem` | '4096' | Worker memory size in MB |
| `worker_cpu` | 4 | Worker CPU (int) |
| `n_worker` | 0 | Int |
| `master_mem` | '32000' | Memory |
| `master_cpu` | 8 | Int |
| `extra_disks` | 0 | Number of extra disks to add |
| `extra_disk_size` | 100 | Extra disk dize in GB |
| `installodf` | `'true'` or `'false'` | `true` if the cluster is a 3-node and ODF will be configured |
| `installocpvirt` | `'true'` or `'false'` | `true` if the cluster is a 3-node with ODF and OpenShift Virtualization will be configured |
| `local_quay_registry` | '' | Local Quay URL to use as local mirror for OCP (if Red Hat Quay is configured) |
| `admin_user` | "admin" | Configures a user to access the cluster using HTPasswd. Empty Value "" means the user will not be configured |
| `htpasswd_pass` | 'Redhat@123' | Password to admin_user |
| `remove_kubeadmin_user` | `'true'` or `'false'` | Remove kubeadmin user after install the cluster |
| `ssh_rsa`  | ssh-rsa AAAAB3Nza... | SSH Pubkey to access OCP nodes over SSH |
| `pullsecret` | '{"auths":{"cloud.op..}}' | pull secret to download OpenShift images |

```
vim ansible-vars-kvm.yaml
```

## Install Required Ansible Collections

Some Ansible collections are required to run this playbook. Install them by running:

```
ansible-galaxy collection install -r requirements.yml
```

# Usage

## Creating the cluster

Once the prerequisites are met and variables are configured, run the playbook as follows:

```
ansible-playbook -e @ansible-vars-kvm.yaml create-cluster-upi-kvm.yaml
```

## Accessing the cluster

The access to the cluster can be using the kubeconfig file generated on '{{ clusters_dir }}/{{ clustername }}/auth/kubeconfig'

```
export KUBECONFIG='{{ clusters_dir }}/{{ clustername }}/auth/kubeconfig'
```

# Day 2 Operations

## Add new worker nodes

To add new nodes after installing the cluster you can use the playbook `add-new-nodes.yaml`

Edit the variables file and configure `n_worker` value

```
vim ansible-vars-kvm.yaml
```

Execute the playbook

```
ansible-playbook -e @ansible-vars-kvm.yaml add-new-nodes.yaml
```

## Configure LVM Storage

To configure LVM storage using the Logical Volume Manager (LVM) Operator after the cluster is up, you can use the playbook `d2-lvm-storage.yaml`.

### Prerequisites:

Ensure that your cluster was created with at least 1 extra disk and the `ansible-vars-kvm.yaml` file is correctly configured, including the following parameters:

- `extra_disks`: Number of extra disks you have configured for extra disks creation. The playbook will automatically generate the corresponding disk names (e.g., `vdb`, `vdc`).

### Steps:

1. **Execute the playbook**:
```
ansible-playbook -e @ansible-vars-kvm.yaml d2-lvm-storage.yaml
```

This playbook performs the following tasks:

- Creates the necessary namespace (`openshift-storage`).
- Installs the LVM Operator from the Red Hat Operator Hub.
- Configures the LVMCluster resource based on the available extra disks.
- Creates a test PersistentVolumeClaim (PVC) and a Pod in the `default` namespace to verify the storage functionality.