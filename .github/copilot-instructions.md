# OpenShift UPI KVM Automation - AI Agent Instructions

## Project Overview

This is an Ansible-based automation for deploying OpenShift 4 clusters on KVM using User-Provisioned Infrastructure (UPI). It supports Single Node OpenShift (SNO) and 3-node clusters with optional OpenShift Data Foundation (ODF) and OpenShift Virtualization.

**Architecture**: Modular Ansible role structure with sequential task execution orchestrated through `roles/ocp_cluster/tasks/main.yaml`.

## Critical Architecture Concepts

### Deployment Flow (roles/ocp_cluster/tasks/main.yaml)
1. **Validate** → **Prerequisites** → **Cleanup** (conditional)
2. **Download Resources** → **Prepare Cluster** → **Create Initial Network** (if dedicated network enabled)
3. **Create VMs** → **Configure Network** (update with DNS entries)
4. **Create Workers** (conditional) → **Install Cluster**
5. **Configure Auth** (conditional) → **Configure Storage** (conditional) → **Configure Virtualization** (conditional)

Each step is an `include_tasks` that can be independently modified. Tasks are NOT tagged for selective execution.

**Important**: When `ocp_cluster_use_dedicated_network: true` (default), a dedicated libvirt network `<clustername>-net` is created in TWO stages:
- **Stage 1** (`create_initial_network.yaml`): Creates basic network with DHCP only, BEFORE VMs exist
- **Stage 2** (`configure_libvirt_network.yaml`): Updates network with DNS entries and static DHCP reservations, AFTER VMs get IPs

### SNO vs 3-Node Decision Tree
The `sno` variable fundamentally changes the deployment:
- **SNO** (`sno: 'true'`): Single master, no load balancer, uses `create single-node-ignition-config`, embeds ignition in ISO
- **3-Node** (`sno: 'false'`): 3 masters + optional workers, requires HAProxy load balancer, uses `create ignition-configs`

Check the `sno` conditional in task files before making changes.

### Ignition and RHCOS Boot Process
- Ignition configs are generated in `roles/ocp_cluster/tasks/generate_ignition.yaml`
- For SNO: ignition is embedded directly into `rhcos-master.iso` using `coreos-installer iso ignition embed`
- For 3-node: bootstrap.ign served via HTTP, master/worker ignitions embedded in ISOs
- VMs boot from ISO, ignition configures CoreOS, then boots from disk

### Network Configuration Pattern
**Dedicated Network Mode** (`ocp_cluster_use_dedicated_network: true` - default):
- Creates isolated libvirt network `<clustername>-net` per cluster
- Two-stage creation process:
  1. **Initial network** (`create_initial_network.yaml`): Basic DHCP-only network created BEFORE VMs
  2. **DNS-enhanced network** (`configure_libvirt_network.yaml`): Network updated with DNS entries AFTER VMs have IPs
- Network automatically cleaned up when cluster is destroyed
- Templates: `libvirt-network-*-initial.xml.j2` for stage 1, `libvirt-network-*.xml.j2` for stage 2

**Shared Network Mode** (`ocp_cluster_use_dedicated_network: false`):
- Uses existing network specified in `kvmnetwork` variable (e.g., 'default')
- Network configuration backed up before modification
- Original config restored on cluster destroy
- Useful for multiple clusters sharing same network

**DNS Integration**:
- Uses dnsmasq via NetworkManager for DNS/DHCP
- HAProxy load balancer for 3-node: API (6443), machine-config (22623), HTTP (80), HTTPS (443)
- VMs get dynamic IPs first, then MAC addresses registered for static DHCP reservations
- Wildcard DNS for `*.apps.<clustername>.<basedomain>` points to master-0 (SNO) or load balancer (3-node)

## Variable Configuration (`ansible-vars-kvm.yaml`)

**Critical Variables**:
- `clustername`: Used as prefix for VMs, DNS entries, directories (e.g., `funny-flanders-master-0`)
- `basedomain`: Must NOT be `.local` (DNS resolution issues) - use real domain like `chiaret.to`
- `clusters_dir`: Base path for cluster artifacts (default: `/vms/clusters` or `/labs`)
- `sno`: `'true'` or `'false'` (string, not boolean!)
- `ocp_cluster_use_dedicated_network`: `true` (default) creates isolated network per cluster, `false` uses existing `kvmnetwork`
- `kvmnetwork`: Only used when `ocp_cluster_use_dedicated_network: false` - specifies existing network name (default: 'default')
- `extra_disks`: Number of extra disks per VM (0-10), required for ODF/LVM storage
- `installodf`: Only works with `sno: 'false'` and `extra_disks >= 1`

**Resource Allocation Logic**:
- SNO typically: `master_mem: '32000'`, `master_cpu: 8`, `n_worker: 0`
- 3-node: `master_mem: '16000'`, `master_cpu: 4`, distribute load across masters
- Workers: Only created if `n_worker > 0`, use `worker_mem` and `worker_cpu`

## Day 2 Operations

### Adding Workers (`add-new-nodes.yaml`)
1. Checks current worker count via `virsh list`
2. Asserts `n_worker` is greater than current count
3. Deploys CSR auto-approver cronjob (in `ocp-csr-approver` namespace)
4. Creates VMs, waits for IPs, copies `worker.ign`, runs `coreos-installer`, reboots
5. **Important**: Pauses CSR approver after nodes join to prevent auto-approval of rogue CSRs

### LVM Storage (`d2-lvm-storage.yaml`)
- Requires `extra_disks >= 1` (checks master-0 XML)
- Installs LVMS operator in `openshift-storage` namespace
- Auto-detects available disks: `vdb`, `vdc`, etc. based on `extra_disks` count
- Creates test PVC (`example-pvc-rwo`) and busybox pod for validation

### ODF Installation
- Triggered during main playbook if `installodf: 'true'` and `sno: 'false'`
- Manifests injected PRE-ignition in `generate_ignition.yaml` (numbered 98_*, 99_*)
- Operators: local-storage, ODF, optionally OCP Virtualization
- Post-install: `configure_storage.yaml` creates LVMCluster and StorageCluster

## Development Conventions

### Template Naming Pattern
- `*-sno.j2`: SNO-specific templates
- `*-3node.j2`: 3-node cluster templates
- `*-initial.j2`: Initial/basic configuration (e.g., network before DNS entries)
- `*-external-kvm.j2`: External KVM host scenarios
- Numbered prefixes: `98_*` for namespaces, `99_*` for operators (manifest application order)

### File Locations
- Cluster artifacts: `{{ clusters_dir }}/{{ clustername }}/` (install-config.yaml, ignition files, auth/)
- Downloaded binaries: `{{ clusters_dir }}/{{ clustername }}/` (openshift-install, oc, kubectl)
- VM disks: `{{ clusters_dir }}/{{ clustername }}/*.qcow2`
- ISOs: `{{ clusters_dir }}/{{ clustername }}/rhcos-*.iso`
- VM management scripts: `{{ clusters_dir }}/{{ clustername }}/startvms.sh` and `stopvms.sh`

### Testing Approach
- No formal test suite
- Validation via actual cluster deployments
- Check `.openshift_install.log` for installation issues
- Use `oc get clusteroperators` to verify operator status

## Common Workflows

### Create New Cluster
```bash
vim ansible-vars-kvm.yaml  # Configure cluster
./run-modular-playbook.sh  # Or: ansible-playbook -e @ansible-vars-kvm.yaml create-cluster-upi-kvm-modular.yaml
export KUBECONFIG="/vms/clusters/funny-flanders/auth/kubeconfig"
oc get nodes
```

### Destroy and Recreate
Set `destroy_if_exists: 'true'` in vars, then run playbook. Cleanup task (`cleanup.yaml`) removes VMs, network config, and directories.

### Access External KVM Cluster
Use `external-kvm-server.yaml` to configure local machine as client for cluster on remote KVM host. Sets up dnsmasq forwarding and HAProxy for API access.

### Start/Stop VMs
Auto-generated scripts in cluster directory:
```bash
cd {{ clusters_dir }}/{{ clustername }}
./startvms.sh              # Start all cluster VMs
./stopvms.sh               # Graceful shutdown
./stopvms.sh force         # Force immediate shutdown
```
Scripts handle SNO vs 3-node configurations automatically.

### Debug Installation Failures
1. Check logs: `tail -f {{ clusters_dir }}/{{ clustername }}/.openshift_install.log`
2. VM console: `virsh console {{ clustername }}-master-0`
3. Bootstrap VM (3-node only): `ssh core@<bootstrap-ip>` then `journalctl -u bootkube`
4. CSRs stuck: `oc get csr -o name | xargs oc adm certificate approve`

## Dependencies

**Ansible Collections** (requirements.yml):
- `kubernetes.core`: K8s resource management
- `community.libvirt`: VM/network operations
- `community.general`: Utilities (xml parsing, seport)
- `ansible.posix`: Firewall, system tasks

**System Packages** (installed by prerequisites.yaml):
- KVM/libvirt stack: `qemu-kvm`, `libvirt`, `virt-install`
- Tools: `coreos-installer`, `guestfs-tools`
- Python: `kubernetes`, `passlib` pip packages

## Critical Gotchas

1. **String Booleans**: Variables like `sno`, `installodf`, `ocp_cluster_use_dedicated_network` are strings `'true'`/`'false'`, not YAML booleans
2. **Avoid `.local` Domains**: dnsmasq/libvirt integration issues, use real domains
3. **Network Creation Order**: When using dedicated networks, network MUST exist before VMs are created. The `create_initial_network.yaml` task handles this.
4. **ODF Limitations**: Only works with 3-node (`sno: 'false'`), requires `extra_disks >= 1`
5. **Bootstrap VM Lifecycle**: 3-node clusters create temporary bootstrap VM, auto-removed after control plane initializes
6. **CSR Auto-Approval**: Worker additions enable cronjob, must pause after completion
7. **NetworkManager Dependency**: DNS resolution relies on NetworkManager + dnsmasq integration, modifying may break cluster access
8. **Memory Requirements**: SNO needs 32GB+, 3-node with workers needs 64GB+ host RAM
9. **Network IP Range**: Each cluster gets a random /24 network in the 192.168.150-170.0/24 range to avoid conflicts
10. **Cleanup Principle**: Everything configured during cluster creation MUST have a corresponding cleanup task in the destroy process. This includes:
    - Network configurations (libvirt networks)
    - DNS entries in /etc/resolv.conf
    - Firewall rules
    - System service configurations
    - Temporary files and directories
    When adding new features, always implement both creation AND cleanup/removal tasks.

## When Modifying

- **Add new task file**: Include it in `roles/ocp_cluster/tasks/main.yaml` sequence with appropriate conditionals
- **Add new template**: Place in `templates/`, use `{{ item }}.yaml.j2` pattern for loops
- **Change VM specs**: Edit `master_mem`, `master_cpu` in defaults or vars
- **Add new conditional feature**: Follow ODF/OCP Virt pattern: manifest injection in `generate_ignition.yaml`, post-install config in separate task file
- **Modify network**:
  - For dedicated networks: Update both `libvirt-network-*-initial.xml.j2` (basic) and `libvirt-network-*.xml.j2` (with DNS)
  - Initial network is created in `create_initial_network.yaml` BEFORE VMs
  - DNS-enhanced network is applied in `configure_libvirt_network.yaml` AFTER VMs get IPs
  - Never try to use VM IPs/MACs in initial network templates - they don't exist yet!
