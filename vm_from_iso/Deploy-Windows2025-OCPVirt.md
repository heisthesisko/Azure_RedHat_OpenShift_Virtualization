# Deploying Windows Server 2025 on OpenShift Virtualization

This guide shows how to install Windows Server 2025 on OpenShift Virtualization (OCP Virt) using ISO media and VirtIO drivers.

---

## Prerequisites
- OpenShift cluster with **Virtualization Operator** installed
- `oc` CLI and `virtctl` available
- Storage class configured
- Files:
  - `Windows_Server_2025.iso`
  - `virtio-win.iso` (drivers from Fedora project)

---

## Steps

### 1. Create Namespace
```bash
oc new-project win2025-demo
```

### 2. Create a Blank Disk
```bash
oc apply -f - <<EOF
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
        storage: 100Gi
  source:
    blank: {}
EOF
```

### 3. Upload ISOs
```bash
virtctl image-upload dv win2025-iso   --size=8Gi   --image-path=./Windows_Server_2025.iso   --uploadproxy-url=https://cdi-uploadproxy-openshift-cnv.apps.<cluster-domain>   --insecure -n win2025-demo

virtctl image-upload dv virtio-drivers   --size=2Gi   --image-path=./virtio-win.iso   --uploadproxy-url=https://cdi-uploadproxy-openshift-cnv.apps.<cluster-domain>   --insecure -n win2025-demo
```

### 4. Create the Virtual Machine
```bash
oc apply -f - <<EOF
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: win2025-vm
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
```

### 5. Start the VM
```bash
virtctl start win2025-vm -n win2025-demo
```

### 6. Connect to Console
```bash
virtctl vnc win2025-vm -n win2025-demo
```
Or use the OpenShift web console → Virtualization → VirtualMachines → `win2025-vm` → **Console**.

---

## Installation Steps (inside Windows Setup)

1. Boot from **Windows Server 2025 ISO**.
2. At disk selection, choose **Load Driver** → browse to the **virtio-win.iso** CD → install `vioscsi` and `netkvm`.
3. Select the 100Gi `win-disk` and continue installation.
4. Proceed with Windows setup.

---

## Post-Install Cleanup
1. Shut down VM:
   ```bash
   virtctl stop win2025-vm -n win2025-demo
   ```
2. Edit the VM to **remove CD-ROMs** (`win2025-iso` and `virtio-drivers`).
3. Restart VM to boot directly from disk:
   ```bash
   virtctl start win2025-vm -n win2025-demo
   ```

---

## Optional Enhancements
- Install full **VirtIO driver pack** inside Windows
- Install **QEMU guest agent** for improved integration (IP, shutdown, metrics)
- Configure RDP or WinRM for remote management
