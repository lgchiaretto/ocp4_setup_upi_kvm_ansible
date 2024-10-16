# OpenShift 4 Automated Cluster Installation (UPI on KVM) using Ansible

This automation helps you create an OpenShift Single Node Cluster (SNO) or 3-node cluster on a KVM host using Libvirt.

## ⚠️ Important Notice

Please exercise caution when running this playbook, as the initial tasks modify network settings. Ensure that you fully understand the changes being made and have appropriate backups or recovery plans in place before proceeding. Running these tasks without careful review may lead to connectivity issues or unintended network configuration changes.

## Tested Environments

This playbook has been successfully tested on the following distributions:

    Fedora 40
    RHEL 8
    RHEL 9

Ensure that your environment meets these system requirements for the best results.

# Prerequisites

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

```
vim ansible-vars-kvm.yaml
```

## Install Required Ansible Collections

Some Ansible collections are required to run this playbook. Install them by running:

```
ansible-galaxy collection install -r requirements.yml
```

# Usage

Once the prerequisites are met and variables are configured, run the playbook as follows:

```
ansible-playbook -e @ansible-vars-kvm.yaml create-cluster-upi-kvm.yaml
```

