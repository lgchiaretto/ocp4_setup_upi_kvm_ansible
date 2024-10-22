# OpenShift 4 Automated Cluster Installation (UPI on KVM) using Ansible

This automation helps you create a Single Node OpenShift (SNO) or 3-node cluster on a KVM host using Libvirt.

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

Use the variable `destroy_if_exists = 'true'` if you would like to remove an existing cluster before creating a new one

If you are creating a Single Node OpenShift you must use `sno = 'true'`

If you are creating a 3-node cluster you must use `sno = 'false'`

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