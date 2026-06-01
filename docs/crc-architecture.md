# CRC System Architecture

CRC (CodeReady Containers) runs a minimal single-node OpenShift cluster inside a local virtual machine. The system is split into two repositories:

- **`snc/`** — builds the VM image (the "bundle")
- **`crc/`** — the user-facing CLI that manages the VM lifecycle

---

## snc/ — Image Builder

Shell scripts that provision a single-node OpenShift cluster on a temporary libvirt VM, configure it for local development use, then package the VM disk into a distributable bundle.

### Build Pipeline

```
snc.sh                          Main orchestrator
  ├─ Generate SSH keypair       id_ecdsa_crc (ECDSA 521-bit, user "core")
  ├─ Create libvirt network     192.168.126.0/24, static IP .11
  ├─ Download RHCOS ISO         Embed Ignition config via coreos-installer
  ├─ virt-install               Boot single-node VM from ISO
  ├─ openshift-install          Wait for bootstrap → cluster operators stabilize
  ├─ Cluster patching           Scale ingress, configure registry, create PVs,
  │                             rotate certs, install kubelet cred manager
  ├─ User setup                 kubeadmin (random password), developer/developer
  ├─ Cleanup                    Remove pull secret, prune images/pods/logs
  └─ Shutdown VM

createdisk.sh                   Package into distributable bundle
  ├─ Sparsify qcow2             Zero free space, convert with lazy_refcounts
  ├─ Convert per platform       qcow2 (libvirt), vhdx (Hyper-V), raw (vfkit)
  ├─ Assemble .crcbundle        Tarball (zstd --ultra -22) containing:
  │   ├─ crc.qcow2              VM disk image
  │   ├─ kubeconfig             Cluster access config
  │   ├─ id_ecdsa_crc           SSH private key for core user
  │   ├─ oc                     OpenShift CLI binary
  │   └─ crc-bundle-info.json   Bundle metadata (version, IPs, file hashes)
  └─ GPG sign + container image (gen-bundle-image.sh)
```

### Key Files

| File | Purpose |
|------|---------|
| `snc.sh` | Main build orchestrator |
| `createdisk.sh` | Disk image creation and bundle packaging |
| `snc-library.sh` | Shared functions (preflight, SSH, cert rotation) |
| `createdisk-library.sh` | Disk manipulation (sparsify, convert, bundle) |
| `tools.sh` | Tool paths and prerequisites |
| `install-config.yaml` | OpenShift installer input template |
| `systemd/` | 19 service units copied into the VM image |
| `microshift.sh` | Bootc-based MicroShift image builder |

### Systemd Services Baked Into the VM

| Service | Role |
|---------|------|
| `crc-dnsmasq.service` | DNS for cluster domains |
| `crc-pullsecret.service` | Load pull secret from `/opt/crc/pull-secret` |
| `ocp-userpasswords.service` | Apply kubeadmin/developer passwords at boot |
| `ocp-mco-sshkey.service` | Update SSH authorized keys via machine config |
| `ocp-custom-domain.service` | Configure custom cluster domain |
| `ocp-clusterid.service` | Set cluster ID |
| `ocp-cluster-ca.service` | Install custom CA certificate |
| `gv-user-network@tap0.service` | gvisor-tap-vsock networking |
| `qemu-guest-agent.service` | QEMU guest agent over vsock |

### Security: What Is NOT in the Final Image

- Kubeadmin password (deleted after cluster setup, redacted from logs)
- Pull secret (removed from disk before bundling)
- Bootstrap artifacts (cleaned up)

---

## crc/ — User-Facing CLI

Go application (`github.com/crc-org/crc/v2`) providing VM lifecycle management, cluster access, and a daemon API.

### Architecture Overview

```
CLI (Cobra commands)
  └─ daemonclient (Unix socket / named pipe)
       └─ daemon HTTP API
            └─ machine.Client interface
                 └─ Platform driver (libvirt / vfkit / libhvee)
                      └─ libmachine (VM state persistence)
                           └─ SSH runner (core@VM)
```

### CLI Commands

| Command | Purpose |
|---------|---------|
| `crc setup` | Install prerequisites (hypervisor, DNS, admin helper) |
| `crc start` | Unpack bundle, create VM, boot cluster |
| `crc stop` | Shut down VM |
| `crc delete` | Remove VM and state |
| `crc status` | Show cluster status |
| `crc console` | Open web console (`--credentials` for login info, `--url` for URL) |
| `crc ip` | Print VM IP address |
| `crc oc-env` | Print shell env for `oc` CLI |
| `crc podman-env` | Print shell env for podman remote |
| `crc config` | Get/set/unset configuration |
| `crc bundle` | Bundle management |

### Key Packages

| Package | Path | Responsibility |
|---------|------|----------------|
| `machine` | `pkg/crc/machine/` | VM lifecycle (start, stop, delete, status) |
| `ssh` | `pkg/crc/ssh/` | SSH client, key management, command execution |
| `bundle` | `pkg/crc/machine/bundle/` | Bundle extraction, metadata, caching |
| `drivers` | `pkg/drivers/` | Platform hypervisor drivers |
| `network` | `pkg/crc/network/` | Network modes, DNS configuration |
| `cluster` | `pkg/crc/cluster/` | Kubernetes/OpenShift operations |
| `api` | `pkg/crc/api/` | REST API for daemon |
| `config` | `pkg/crc/config/` | Viper-based configuration |
| `preflight` | `pkg/crc/preflight/` | System requirement checks |
| `preset` | `pkg/crc/preset/` | Preset support (OpenShift, OKD, MicroShift) |
| `services` | `pkg/crc/services/` | Host services (DNS, admin helper) |
| `constants` | `pkg/crc/constants/` | Paths, defaults, public keys |
| `libmachine` | `pkg/libmachine/` | Machine state persistence (forked from Docker Machine) |

### Platform Drivers

| Driver | Platform | Package |
|--------|----------|---------|
| libvirt/KVM | Linux | `pkg/crc/machine/libvirt/` |
| vfkit | macOS | `pkg/drivers/vfkit/` |
| Hyper-V | Windows | `pkg/drivers/libhvee/` |

### Networking Modes

| Mode | Platform | VM Address | SSH Port | How It Works |
|------|----------|-----------|----------|-------------|
| System | Linux (default) | 192.168.130.11 | 22 | VM gets a real IP on a libvirt NAT network |
| User/vsock | macOS, Windows | 127.0.0.1 | 2222 | VM tunneled via vsock to localhost |

### Bundle Lifecycle

1. **Download** — fetch `.crcbundle` from registry, verify GPG signature
2. **Extract** — unpack zstd tarball to `~/.crc/cache/crc_<preset>_<driver>_<version>_<arch>/`
3. **Start** — copy disk image to `~/.crc/machines/crc/`, create VM via driver, boot
4. **Post-boot** — resize disk, configure DNS, set pull secret, update SSH keys, wait for cluster health

### File Locations on the Host

| Path | Contents |
|------|----------|
| `~/.crc/machines/crc/` | Active VM disk, config, SSH keys |
| `~/.crc/machines/crc/id_ed25519` | SSH private key (Ed25519, generated by crc) |
| `~/.crc/machines/crc/id_ecdsa` | SSH private key (ECDSA, from bundle, fallback) |
| `~/.crc/cache/` | Extracted bundle cache |
| `~/.crc/crc.json` | CRC configuration |

---

## SSH Access to the CRC VM

The VM runs Red Hat CoreOS with a `core` user. SSH is the only shell access method. No password authentication — public key only.

### How SSH Keys Get Into the VM

1. **Image build time** (`snc/snc.sh`): an ECDSA 521-bit keypair (`id_ecdsa_crc`) is generated and the public key is embedded in the Ignition config, which seeds `core`'s `authorized_keys`.
2. **Bundle packaging** (`snc/createdisk.sh`): the private key is included in the `.crcbundle`.
3. **First start** (`crc/pkg/crc/machine/start.go`): CRC generates a new Ed25519 keypair (`id_ed25519`) and copies it into the VM, adding it to authorized keys alongside the original bundle key.

### How to SSH Into the CRC VM

**Option 1 — Use the `crc` CLI to get connection details, then ssh manually:**

```bash
# Get the VM IP
crc ip

# SSH in (Linux, system networking mode)
ssh -i ~/.crc/machines/crc/id_ecdsa -o StrictHostKeyChecking=no core@$(crc ip)

# SSH in (macOS/Windows, user networking mode via vsock)
ssh -i ~/.crc/machines/crc/id_ecdsa -o StrictHostKeyChecking=no -p 2222 core@127.0.0.1
```

**Option 2 — Use the Ed25519 key (generated by crc on first start):**

```bash
ssh -i ~/.crc/machines/crc/id_ed25519 -o StrictHostKeyChecking=no core@$(crc ip)
```

**Option 3 — Use the bundle's original key directly:**

```bash
# The bundle key is also available in the cache directory
ssh -i ~/.crc/cache/crc_*/id_ecdsa_crc -o StrictHostKeyChecking=no core@$(crc ip)
```

### Connection Details Summary

| Detail | System networking (Linux) | User networking (macOS/Windows) |
|--------|--------------------------|--------------------------------|
| **User** | `core` | `core` |
| **Host** | `192.168.130.11` (or `crc ip` output) | `127.0.0.1` |
| **Port** | 22 | 2222 |
| **Key** | `~/.crc/machines/crc/id_ecdsa` or `id_ed25519` | same |
| **Password** | none (key-only) | none (key-only) |

### Once Inside the VM

```bash
# Become root
sudo -i

# Use oc against the local cluster
export KUBECONFIG=/opt/kubeconfig
oc get nodes

# Check cluster operators
oc get co

# Access CRC-specific config
ls /opt/crc/
```

### Using crictl Inside the VM

CRC runs CRI-O as its container runtime. `crictl` is available on the VM for low-level container and image inspection — useful for debugging pods that won't start, inspecting pulled images, or clearing image cache.

All `crictl` commands require root. SSH in and `sudo -i` first, or prefix every command with `sudo`.

```bash
# SSH into the VM and become root
ssh -i ~/.crc/machines/crc/id_ecdsa -o StrictHostKeyChecking=no core@$(crc ip)
sudo -i
```

**Listing and inspecting pods:**

```bash
# List all pods (similar to `docker ps` but at the pod sandbox level)
crictl pods

# List pods filtered by namespace
crictl pods --namespace openshift-apiserver

# List pods filtered by state
crictl pods --state ready
crictl pods --state notready

# Inspect a specific pod sandbox (detailed JSON)
crictl inspectp <POD-ID>
```

**Listing and inspecting containers:**

```bash
# List all containers
crictl ps

# Include stopped/exited containers
crictl ps -a

# Filter by pod ID
crictl ps --pod <POD-ID>

# Filter by state
crictl ps --state running
crictl ps --state exited

# Inspect a container (config, mounts, state, PID, etc.)
crictl inspect <CONTAINER-ID>
```

**Container logs and exec:**

```bash
# View container logs
crictl logs <CONTAINER-ID>

# Follow logs
crictl logs -f <CONTAINER-ID>

# Tail last N lines
crictl logs --tail 50 <CONTAINER-ID>

# Exec into a running container
crictl exec -it <CONTAINER-ID> /bin/sh
```

**Image management:**

```bash
# List all images on the node
crictl images

# List images with digests
crictl images --digests

# Pull an image (requires pull secret at /var/lib/kubelet/config.json)
crictl pull <IMAGE>

# Inspect image metadata
crictl inspecti <IMAGE-ID-OR-NAME>

# Remove a specific image
crictl rmi <IMAGE-ID>

# Prune unused images (this is what snc does during image cleanup)
crictl rmi --prune
```

**Runtime and node stats:**

```bash
# Container resource usage (CPU, memory)
crictl stats

# Stats for a specific container
crictl stats <CONTAINER-ID>

# CRI-O runtime info
crictl info
```

**Debugging a crashlooping pod — typical workflow:**

```bash
# Find the pod
crictl pods --name <pod-name-prefix>

# List its containers (including exited ones)
crictl ps -a --pod <POD-ID>

# Check logs of the crashed container
crictl logs <CONTAINER-ID>

# Inspect the container for exit code, OOM kill, etc.
crictl inspect <CONTAINER-ID> | jq '.status.exitCode, .status.reason'
```

### Kubernetes/OpenShift Access (Without SSH)

```bash
# Get credentials for the web console and oc CLI
crc console --credentials

# Typical output:
#   To login as a regular user:   oc login -u developer -p developer https://api.crc.testing:6443
#   To login as an admin:         oc login -u kubeadmin -p <password> https://api.crc.testing:6443

# Set up oc in your shell
eval $(crc oc-env)
oc login -u developer -p developer https://api.crc.testing:6443
```
