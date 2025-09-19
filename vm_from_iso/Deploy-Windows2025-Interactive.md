# Interactive Deployment of Windows Server 2025 on OpenShift Virtualization (Cloud CLI)

This guide shows how to deploy Windows Server 2025 on OpenShift Virtualization **interactively** using the Cloud CLI (`oc` and `virtctl`).  
You can upload the ISO either from your **desktop** or directly from a **web URL**.

---

## Prerequisites
- OpenShift cluster with Virtualization Operator installed
- Access to **Cloud Shell** with `oc` and `virtctl`
- One of the following:
  - Local `Windows_Server_2025.iso` file on your desktop
  - Public web URL hosting the ISO
- `virtio-win.iso` (VirtIO drivers from Fedora project)

---

## Step 1. Create a Project
```bash
oc new-project win2025-interactive
```

---

## Step 2. Create Blank Disk for Windows
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

---

## Step 3. Upload ISOs

### Option A: Upload from Desktop
Run from Cloud CLI (replace `<PATH>` with the ISO location on your desktop if mounted):
```bash
virtctl image-upload dv win2025-iso   --size=8Gi   --image-path=<PATH>/Windows_Server_2025.iso   --uploadproxy-url=https://cdi-uploadproxy-openshift-cnv.apps.<cluster-domain>   --insecure -n win2025-interactive

virtctl image-upload dv virtio-drivers   --size=2Gi   --image-path=<PATH>/virtio-win.iso   --uploadproxy-url=https://cdi-uploadproxy-openshift-cnv.apps.<cluster-domain>   --insecure -n win2025-interactive
```

### Option B: Import from Web URL
If your ISO is hosted on a web server:
```bash
oc apply -f - <<EOF
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: win2025-iso
spec:
  source:
    http:
      url: "https://<your-web-url>/Windows_Server_2025.iso"
  pvc:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 8Gi
EOF

oc apply -f - <<EOF
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: virtio-drivers
spec:
  source:
    http:
      url: "https://<your-web-url>/virtio-win.iso"
  pvc:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 2Gi
EOF
```

---

## Step 4. Create the Virtual Machine
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

---

## Step 5. Start the VM
```bash
virtctl start win2025-vm -n win2025-interactive
```

---

## Step 6. Connect to Console
```bash
virtctl vnc win2025-vm -n win2025-interactive
```
Or use the OpenShift Web Console → Virtualization → VirtualMachines → `win2025-vm` → **Console**.

---

## Step 7. Install Windows
1. Boot from **Windows Server 2025 ISO**.  
2. At disk selection, click **Load Driver** → browse to **virtio-win.iso** → install `vioscsi` and `netkvm`.  
3. Select the blank 100Gi disk and proceed with installation.  

---

## Step 8. Post-Install Cleanup
```bash
virtctl stop win2025-vm -n win2025-interactive
```
Remove ISO disks (`win2025-iso`, `virtio-drivers`), then restart:
```bash
virtctl start win2025-vm -n win2025-interactive
```

Now the VM boots from the installed Windows Server 2025 image.

---

✅ You have completed an **interactive deployment** using Cloud CLI with either desktop upload or web URL import.
