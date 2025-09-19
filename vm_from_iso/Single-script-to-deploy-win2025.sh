#!/usr/bin/env bash
set -euo pipefail

# =======================================================
# Deploy Windows Server 2025 VM on OpenShift Virtualization
# =======================================================

# --- VARIABLES ---
NAMESPACE="win2025-demo"
VM_NAME="win2025-vm"
DISK_SIZE="100Gi"
ISO_SIZE="8Gi"
VIRTIO_SIZE="2Gi"
WIN_ISO="./Windows_Server_2025.iso"   # <-- Replace with your ISO path
VIRTIO_ISO="./virtio-win.iso"         # <-- Replace with your ISO path
UPLOAD_URL="https://cdi-uploadproxy-openshift-cnv.apps.<cluster-domain>" # <-- Replace with your cluster domain

# --- CREATE NAMESPACE ---
echo "[INFO] Creating namespace: $NAMESPACE"
oc new-project $NAMESPACE || oc project $NAMESPACE

# --- CREATE BLANK DISK PVC ---
echo "[INFO] Creating blank disk DataVolume ($DISK_SIZE)"
cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: win2025-disk
spec:
  pvc:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: $DISK_SIZE
  source:
    blank: {}
EOF

# --- UPLOAD WINDOWS ISO ---
echo "[INFO] Uploading Windows Server 2025 ISO..."
virtctl image-upload dv win2025-iso   --size=$ISO_SIZE   --image-path=$WIN_ISO   --uploadproxy-url=$UPLOAD_URL   --insecure -n $NAMESPACE

# --- UPLOAD VIRTIO DRIVERS ISO ---
echo "[INFO] Uploading VirtIO drivers ISO..."
virtctl image-upload dv virtio-drivers   --size=$VIRTIO_SIZE   --image-path=$VIRTIO_ISO   --uploadproxy-url=$UPLOAD_URL   --insecure -n $NAMESPACE

# --- CREATE VM ---
echo "[INFO] Creating VirtualMachine ($VM_NAME)"
cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: $VM_NAME
spec:
  running: false
  template:
    spec:
      domain:
        cpu:
          cores: 4
        resources:
          requests:
            memory: 8Gi
        devices:
          disks:
            - name: win-disk
              disk:
                bus: virtio
            - name: win2025-install
              cdrom:
                bus: sata
            - name: virtio-drivers
              cdrom:
                bus: sata
      volumes:
        - name: win-disk
          dataVolume:
            name: win2025-disk
        - name: win2025-install
          dataVolume:
            name: win2025-iso
        - name: virtio-drivers
          dataVolume:
            name: virtio-drivers
EOF

# --- START VM ---
echo "[INFO] Starting VM ($VM_NAME)"
virtctl start $VM_NAME -n $NAMESPACE

# --- CONNECT ---
echo "[INFO] VM is starting. Use the following to connect via VNC:"
echo "virtctl vnc $VM_NAME -n $NAMESPACE"
