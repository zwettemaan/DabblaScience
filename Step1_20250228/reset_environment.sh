#!/bin/bash
VM_NAME="python-ds"
echo "Resetting Python data science environment..."
multipass stop $VM_NAME
multipass delete $VM_NAME
multipass purge
echo "Environment reset complete. Run setup script again to create a fresh VM."
