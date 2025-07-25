#!/bin/bash

# Usage: ./run-modular-playbook.sh [options]

set -e

PLAYBOOK="create-cluster-upi-kvm-modular.yaml"
VARS_FILE="ansible-vars-kvm.yaml"

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -v, --vars-file FILE    Specify vars file (default: ansible-vars-kvm.yaml)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                         # Use default settings"
    echo "  $0 -v custom-vars.yaml                     # Use custom vars file"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--vars-file)
            VARS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ ! -f "$PLAYBOOK" ]]; then
    echo "Error: Playbook '$PLAYBOOK' not found!"
    exit 1
fi

if [[ ! -f "$VARS_FILE" ]]; then
    echo "Error: Variables file '$VARS_FILE' not found!"
    exit 1
fi

echo "=============================================="
echo "Running OpenShift UPI KVM Modular Playbook"
echo "=============================================="
echo "Playbook: $PLAYBOOK"
echo "Vars file: $VARS_FILE"
echo "=============================================="

# Run the playbook
ansible-playbook "$PLAYBOOK" -e "@$VARS_FILE" "${@}"

echo "=============================================="
echo "Playbook execution completed!"
echo "=============================================="
