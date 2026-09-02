# Arch AI Engineering and Red-Team OS Blueprint

**Note (31 August 2026):** this project is now officially named **JAZZ**, built by Akash Navet, Holy Cow Studios Pvt Ltd, and Claude. This document is the original foundational vision — kept as historical record; see `Blueprint_Phase1_AI_Engineering_First.md`, `SPEC.md`, and `Research-Reference-List.md` for JAZZ's current, narrower Phase 1 scope and naming.

**Document status:** Foundational vision and research blueprint  
**Date:** 28 August 2026  
**Purpose:** Personal use, learning, security research, AI engineering and authorised red-teaming  
**Base:** Arch Linux, Linux kernel and Unix design philosophy

---

## 1. Executive Summary

This project proposes a modern Arch-based Linux distribution designed as a secure, visually distinctive workstation for:

- AI and machine-learning engineering
- Local model inference and experimentation
- MLOps and AI application development
- AI and agentic-system red-teaming
- Authorised conventional cybersecurity red-teaming
- Systems engineering education
- Personal productivity and creative experimentation

The operating system should combine a gorgeously animated, keyboard-first Wayland desktop with reproducible AI environments and strongly isolated security laboratories. It should remain understandable, modular, secure, repairable and aligned with the practical Unix philosophy.

The recommended architecture is not to install every AI and security package directly on the main system. Instead, the OS should consist of:

1. A small, trusted Arch host
2. Reproducible AI containers with controlled GPU access
3. Disposable red-team virtual machines and isolated networks
4. Native development and diagnostic tools
5. A custom animated desktop shell
6. Snapshots, rollback and a dependable recovery environment

This is initially an **Arch-based distribution**, not a new kernel or entirely new operating system. It can evolve into a more independent distribution only after its base architecture, packages, installer, update process and security model are dependable.

---

## 2. Vision

> Build a modern Arch-based operating system that combines a beautifully animated, keyboard-first desktop with a complete AI engineering environment and strongly isolated laboratories for cybersecurity and AI red-teaming. The system should remain transparent, modular, reproducible, secure and repairable in accordance with the Unix philosophy.

### 2.1 Intended identity

The distribution should be recognisable through the following qualities:

- AI development available immediately after installation
- First-class local inference and GPU-aware workflows
- Dedicated AI-security and adversarial-testing environments
- Disposable, isolated offensive-security laboratories
- An original, highly animated Wayland interface
- Arch simplicity and transparency below the graphical experience
- Reproducible profiles instead of uncontrolled package accumulation
- Strong recovery, rollback and diagnostic capabilities

### 2.2 Primary users

The first release is for one principal user: its developer. Future audiences may include:

- AI engineers
- Machine-learning researchers
- AI security researchers
- Penetration testers working in authorised environments
- Linux learners and systems engineers
- Developers who want local-first AI workflows

### 2.3 Non-goals for early releases

Early releases should not attempt to:

- Write a new kernel
- Replace `pacman`
- Maintain a complete independent package ecosystem
- Support every CPU architecture and hardware combination
- Preinstall every security tool
- Create a new compositor from scratch
- Guarantee compatibility with every AUR package
- Compete immediately with mature general-purpose distributions

---

## 3. Design Principles

### 3.1 Beautiful but understandable

The interface may be visually ambitious, but it must expose system state. Users should be able to determine what is running, which trust domain it belongs to, what resources it consumes and how it was launched.

### 3.2 Ready without being bloated

Role-based profiles should provide complete workflows without filling the trusted host with unused tools.

### 3.3 Isolation by default

AI experiments, exploit samples and offensive tools should not receive unrestricted access to personal files, credentials or host networking.

### 3.4 GPU-aware operation

The installer and environment manager should identify supported hardware and offer NVIDIA, AMD, Intel or CPU-only profiles without assuming that one AI stack works everywhere.

### 3.5 Reproducibility

Every important environment should be reconstructable using a package manifest, container definition, lockfile or VM template.

### 3.6 Recoverability

Updates should be paired with snapshots or other recovery controls. The user should always have a documented route back to a bootable system.

### 3.7 Unix underneath

Graphical operations should correspond to inspectable commands, configuration files and services. Important functionality should not exist solely behind an opaque interface.

### 3.8 Authorised security research

Red-team functions should clearly communicate laboratory boundaries, target scope and network state. They are intended only for systems the user owns or is explicitly authorised to test.

### 3.9 Tested latest, not blindly newest

“Latest” should mean the newest version that has passed compatibility and security tests. This is particularly important for kernels, GPU drivers, CUDA, ROCm and machine-learning frameworks.

---

## 4. Unix Philosophy for This Project

The Unix philosophy should be interpreted as an engineering discipline rather than an aesthetic slogan.

### 4.1 Do one thing well

Each system component should have a clear responsibility. The installer installs, the updater updates, the environment manager manages environments and the recovery tool restores known-good states.

### 4.2 Compose programs

Components should cooperate through documented interfaces, files, pipes, sockets or APIs rather than hidden coupling.

### 4.3 Prefer inspectable state

The user should be able to inspect:

- Why a service started
- Which package owns a file
- Which environment launched a process
- Which network a laboratory uses
- Which GPU resources a job consumes
- Where configuration originated

### 4.4 Separate policy from mechanism

Example:

- Mechanism: LUKS supports block-device encryption.
- Distribution policy: encryption is offered or enabled by default.

### 4.5 Make components replaceable

Where practical, a user should be able to replace the shell, terminal, editor, model runtime or container image without breaking unrelated subsystems.

### 4.6 Control complexity

Modern Linux desktops, browsers, GPU stacks and security frameworks are inherently complex. The objective is controlled and well-documented complexity, not minimalism at the expense of capability.

---

## 5. System Architecture

```text
Animated Wayland desktop
        |
Trusted Arch host
        |-- Native development and diagnostic tools
        |-- Rootless AI containers
        |      `-- Controlled GPU access
        |-- Isolated red-team virtual machines
        |      `-- Host-only and isolated networks
        `-- Snapshots, rollback and recovery
```

### 5.1 Trusted host

The host should contain only what is required for:

- Booting and hardware operation
- Desktop and audio
- Networking and firewalling
- GPU drivers
- Storage and encryption
- Virtualisation
- Container management
- Essential development
- Updates, security and recovery

Red-team collections, unstable AI dependencies and unknown samples should not be installed directly into the trusted host when a container or VM provides a safer option.

### 5.2 AI engineering layer

AI workloads should primarily use reproducible containers or managed project environments. This reduces conflicts between Python packages, CUDA, ROCm and rapidly changing frameworks.

Recommended principles:

- Rootless Podman as the default container engine
- NVIDIA Container Toolkit for supported NVIDIA hardware
- ROCm-compatible containers for supported AMD hardware
- CPU and Vulkan alternatives where practical
- Project-specific Python environments
- Pinned dependencies and lockfiles
- Explicit model-storage locations
- Resource limits for local inference services

### 5.3 Red-team laboratory layer

QEMU/KVM and libvirt should provide disposable environments such as:

- Kali Linux attacker VM
- Linux server target VM
- Windows target VM
- Active Directory laboratory
- Vulnerable web-application laboratory
- Reverse-engineering environment
- Malware-analysis environment
- AI-model attack laboratory

Laboratory design should support:

- Host-only networks
- Completely isolated networks
- Explicit NAT or internet access
- VM snapshots
- Fast reset to a clean state
- Carefully controlled clipboard and file sharing
- Optional USB or wireless-device passthrough
- Clear visual indication of the active trust domain

### 5.4 Native development layer

The host may include stable and broadly useful tools such as:

- Git
- C/C++ and Rust toolchains
- Python bootstrap tooling
- Shell scripting tools
- Build systems
- Debuggers
- An editor or IDE
- System diagnostics
- QEMU/KVM and container clients

Project-specific runtimes and libraries should remain isolated.

---

## 6. Graphical and Interaction Design

### 6.1 Recommended graphical stack

- **Display architecture:** Wayland
- **Initial compositor:** Hyprland
- **Custom desktop shell:** Quickshell with Qt/QML
- **Audio and screen sharing:** PipeWire
- **Application integration:** XDG Desktop Portals
- **Recovery session:** a minimal compositor or terminal session

Hyprland is appropriate for an early visually ambitious release because it provides dynamic tiling, animation, plugins and IPC. Quickshell can be used to build panels, overlays, widgets, notifications, lock screens and other shell components using QtQuick/QML.

### 6.2 Workspace identities

The interface can organise work into purpose-driven spaces:

| Workspace | Purpose |
| --- | --- |
| **Forge** | Coding and AI application engineering |
| **Lab** | Notebooks, datasets and experiments |
| **Arena** | AI and agentic-system red-teaming |
| **Range** | Conventional cybersecurity laboratory |
| **Observe** | Logs, traffic, metrics and system monitoring |
| **Vault** | Keys, secrets and sensitive projects |

### 6.3 AI Command Centre

A dedicated overlay or dashboard could display:

- GPU utilisation and VRAM
- CPU and memory usage
- Active local models
- Model size and quantisation
- Token throughput
- Container status
- Training or inference jobs
- Jupyter sessions
- Experiment history
- Temperature and power consumption

### 6.4 Functional animation

Animation should communicate meaningful state:

- Workspace transitions indicate a change of trust domain.
- Red borders identify an offensive-security VM.
- Amber indicates an environment with external network access.
- A subtle pulse indicates active GPU inference.
- A shield transition confirms that a disposable lab was reset.
- Network topology animates when a laboratory begins or stops.

### 6.5 Accessibility and performance

The system should support:

- Reduced-motion mode
- Keyboard-only operation
- High-contrast themes
- Scalable text and interface elements
- Screen-reader compatibility where feasible
- Automatic reduction of effects under heavy GPU load
- Reduced animation on battery power
- A recovery interface independent of the primary graphical shell

---

## 7. Package and Profile Architecture

The project should avoid a single enormous package list. It should use signed metapackages or equivalent profiles.

| Profile | Purpose | Representative components |
| --- | --- | --- |
| `os-core` | Secure bootable base | Linux kernel, firmware, systemd, pacman, NetworkManager, nftables |
| `os-desktop` | Animated interface | Hyprland, Quickshell, Qt/QML, PipeWire, portals, fonts |
| `os-dev-base` | General engineering | Git, compilers, CMake, Meson, debuggers, container clients |
| `os-ai-core` | AI development | Python tooling, JupyterLab and reproducible PyTorch definitions |
| `os-ai-local` | Local inference | Ollama, llama.cpp and model-management utilities |
| `os-ai-nvidia` | NVIDIA acceleration | NVIDIA drivers, CUDA integration and container toolkit |
| `os-ai-amd` | AMD acceleration | ROCm-compatible environment and validation tools |
| `os-ai-redteam` | AI security testing | Garak, PyRIT and evaluation templates |
| `os-cyber-lab` | Traditional red-team lab | VM templates, isolated networks and selected tools |
| `os-reversing` | Binary analysis | GDB, Ghidra, radare2 or Rizin, tracing tools |
| `os-recovery` | Repair and rollback | Btrfs utilities, snapshots, rescue image and diagnostics |

Users should be able to select profiles during installation and add or remove them later.

### 7.1 Package trust levels

Packages should be categorised by source and trust:

1. Arch official repositories
2. Distribution-maintained signed repository
3. Verified upstream container images
4. Reviewed AUR recipes
5. Experimental or user-provided packages

AUR content should never be treated as equivalent to signed official packages. Automated source and recipe inspection should occur before it enters a distribution-maintained build.

---

## 8. AI Engineering Capabilities

### 8.1 Model development

The OS should make it easy to create reproducible environments containing:

- Python
- `uv`, `pip` or a selected environment manager
- PyTorch
- Transformers
- Datasets
- Accelerate
- JupyterLab
- TensorBoard
- Experiment tracking
- Dataset and model versioning
- ONNX Runtime
- Profiling and debugging tools

Python AI libraries should not be installed indiscriminately into the system Python environment.

### 8.2 Local inference

The system should support:

- Ollama
- llama.cpp
- OpenAI-compatible local endpoints
- Quantised model formats
- Model download and storage management
- CPU inference
- NVIDIA CUDA acceleration
- AMD ROCm acceleration where supported
- Vulkan acceleration where appropriate
- Per-model CPU, memory and GPU controls

### 8.3 AI application engineering

Optional environments may provide:

- Python and Node.js application stacks
- Containerised PostgreSQL and Redis
- Vector databases
- API-testing clients
- Agent and retrieval frameworks
- Local observability
- Prompt and model evaluation
- Secrets injection without storing secrets in images

### 8.4 MLOps learning

Advanced profiles can teach:

- Container image creation
- Reproducible model environments
- Dataset versioning
- Model registry concepts
- Local CI pipelines
- Optional local Kubernetes
- Evaluation gates
- Monitoring and drift concepts
- Secrets and artefact management

---

## 9. Red-Teaming Capabilities

The project should distinguish conventional cybersecurity red-teaming from AI red-teaming.

### 9.1 Conventional cybersecurity red-teaming

Authorised laboratory profiles may cover:

- Network reconnaissance
- Web and API security assessment
- Wireless assessment
- Active Directory laboratories
- Password auditing
- Reverse engineering
- Exploit-development education
- Digital forensics
- Traffic capture and analysis
- Cloud-security assessment

Representative categories of tooling include:

- Network mapping and service enumeration
- Packet capture and protocol analysis
- Web proxies and application scanners
- Content discovery and fuzzing
- Password and hash auditing
- Directory and identity assessment
- Binary analysis and debugging
- Vulnerability validation
- Evidence collection and reporting

Large toolsets should be supplied through role-based VMs, containers or metapackages instead of being placed directly on the host.

### 9.2 AI and agentic-system red-teaming

The OS should support research into:

- Direct and indirect prompt injection
- Jailbreaking
- Sensitive-data disclosure
- Insecure output handling
- Tool misuse
- Excessive agency
- Retrieval and context poisoning
- Model extraction
- Training-data poisoning
- Unsafe content generation
- Agent memory manipulation
- Insecure extensions, plugins and MCP integrations
- Denial-of-wallet and resource-exhaustion conditions

Core tools and frameworks may include:

- **Garak:** automated probes for undesirable model and application failure modes
- **PyRIT:** automated and human-led generative-AI risk identification
- **OWASP GenAI Red Teaming Guide:** methodology spanning model, implementation, infrastructure and runtime testing
- **OWASP GenAI LLM Top 10:** risk classification for LLM applications
- **MITRE ATLAS:** adversarial tactics and techniques targeting AI systems

AI red-team environments should keep test prompts, target definitions, results and evidence separate from personal projects.

---

## 10. Security Architecture

Security should begin with a threat model rather than a collection of hardening settings.

### 10.1 Threat-model questions

- Is the system defending against physical theft?
- Could untrusted applications or model files be opened?
- Will exploit samples or malware be analysed?
- Are supply-chain compromises in scope?
- Will the system connect to hostile laboratory networks?
- Must sensitive client or research data be protected?
- Is persistence after a host compromise considered?
- Will untrusted USB, Wi-Fi or Bluetooth devices be used?
- What forensic access should be possible after shutdown?

### 10.2 Security concepts to understand

- Confidentiality, integrity and availability
- Authentication and authorisation
- Encryption at rest versus runtime protection
- Secure Boot versus storage encryption
- Application sandboxing versus Unix permissions
- Vulnerability prevention, detection and recovery
- Host isolation versus network isolation
- Trusted source code versus trusted binary artefacts

### 10.3 Candidate controls

- LUKS/dm-crypt full-disk encryption
- UEFI Secure Boot
- Signed packages and repository databases
- AppArmor or SELinux investigation
- Linux capabilities
- Seccomp
- Namespaces and cgroups
- `systemd` service sandboxing
- nftables firewall policy
- VM and container isolation
- Restricted USB passthrough
- Protected signing keys and secrets
- Automatic security-update notification
- Snapshot-based recovery

### 10.4 Important limitation

Full-disk encryption, Secure Boot, sandboxing, signed packages and virtual machines address different threats. No single control makes the system “secure.”

---

## 11. Boot Architecture

The boot chain should be understood and documented end to end:

1. UEFI firmware initialises hardware.
2. Secure Boot may verify the next executable.
3. A bootloader or Unified Kernel Image is loaded.
4. The Linux kernel initialises CPUs, memory and drivers.
5. The initramfs locates and, when necessary, unlocks the root filesystem.
6. The root filesystem is mounted.
7. `systemd` starts services and reaches the intended target.
8. A terminal or graphical session starts.

Important subjects include:

- EFI System Partition
- Unified Kernel Images
- Kernel command-line parameters
- Kernel modules
- Early userspace
- Encrypted-root unlocking
- Boot failure diagnosis
- Fallback kernel and recovery image

For a modern personal system, a Unified Kernel Image with Secure Boot is a strong architecture to investigate. The first release should also retain an LTS fallback kernel.

---

## 12. Filesystems and Storage

Key concepts include:

- GPT partitioning
- EFI System Partition
- Root, home and swap layouts
- Mount points and `/etc/fstab`
- File ownership and permissions
- ACLs and extended attributes
- Symbolic and hard links
- LUKS encryption
- Snapshot design
- Backups and disk-failure recovery

### 12.1 ext4 versus Btrfs

| Filesystem | Strengths | Trade-offs |
| --- | --- | --- |
| ext4 | Simple, mature and straightforward to repair | No native snapshot workflow comparable to Btrfs |
| Btrfs | Snapshots, subvolumes, compression and rollback possibilities | Requires more deliberate layout and recovery design |

Btrfs is recommended for the project because update rollback and disposable development states are valuable learning objectives. The implementation must still be tested and documented carefully.

---

## 13. Processes, Services and Privilege

The project will require knowledge of:

- Process creation and termination
- Signals
- Environment variables
- Standard input, output and error
- Pipes and redirection
- IPC, sockets and D-Bus
- CPU and memory scheduling
- cgroups
- Namespaces
- `systemd` units and targets
- Service supervision and journaling

Identity and privilege concepts include:

- Users, groups, UID and GID
- Root privileges
- `sudo` or `doas`
- Setuid programs
- Linux capabilities
- PAM authentication
- File permissions and ACLs
- Polkit desktop privilege requests

The system should grant narrow capabilities where possible instead of giving an application full root privileges.

---

## 14. Networking

Required concepts include:

- Interfaces and drivers
- DHCP and static addressing
- DNS resolution
- Routing
- Wi-Fi authentication
- NetworkManager or `systemd-networkd`
- nftables
- SSH security
- VPN integration
- Time synchronisation
- Bridges, NAT and isolated virtual networks

Laboratory network modes should be explicit and visible:

| Mode | Behaviour |
| --- | --- |
| Isolated | No host or internet connectivity except explicitly defined peers |
| Host-only | Communication with selected host services, no internet by default |
| NAT | Outbound internet through the host, with restricted inbound access |
| Bridged | Direct presence on a physical network; advanced and potentially risky |

---

## 15. Hardware and GPU Compatibility

Important subjects include:

- Kernel configuration
- Built-in and loadable drivers
- Kernel modules
- `udev`
- CPU microcode
- Linux firmware packages
- Graphics drivers
- Power and thermal management
- Suspend, resume and hibernation
- Bluetooth, Wi-Fi and audio
- GPU compute validation

Useful diagnostic tools include:

- `lspci`
- `lsusb`
- `dmesg`
- `journalctl`
- `lsmod`
- `udevadm`
- Vendor GPU diagnostics

GPU support must be treated as a tested compatibility matrix rather than a simple choice between NVIDIA and AMD.

---

## 16. Update Policy

Arch is a rolling-release distribution, while AI toolchains often require carefully tested version combinations.

| Layer | Recommended update policy |
| --- | --- |
| Desktop and ordinary applications | Current tested Arch stable packages |
| Kernel and GPU drivers | Tested compatibility set with fallback kernel |
| AI environments | Version-pinned containers and lockfiles |
| Red-team tools | Versioned VM or container images |
| AUR packages | Explicit review before inclusion |
| Experimental software | Opt-in testing channel |

Before an update is promoted, automated tests should cover:

- Booting
- Desktop login
- GPU detection
- CUDA or ROCm workload execution
- Rootless containers
- Virtual machines
- Secure Boot
- Laboratory network isolation
- Snapshot restoration
- Package downgrade or recovery

---

## 17. Build and Release Engineering

The project should develop skills and controls in:

- Git-based source control
- `PKGBUILD` creation
- `makepkg`
- Clean chroot builds
- Custom signed repositories
- `archiso`
- Automated ISO creation
- CI pipelines
- Artefact checksums
- Package and ISO signing
- Release versioning
- Reproducible builds
- Testing and experimental channels
- Upgrade and rollback testing

The system should always be reproducible from source-controlled configuration rather than depending on the accidental state of the development machine.

### 17.1 Supply-chain minimums

- Signed Git tags or commits
- Verified upstream source archives
- Isolated package builds
- Signed packages
- Signed repository databases
- Protected signing keys
- Documented key rotation
- Dependency and vulnerability monitoring
- Reproducible-build investigation
- Recovery from a compromised release key

---

## 18. Testing and Debugging

### 18.1 Essential diagnostic tools

- `journalctl`
- `dmesg`
- `systemctl`
- `strace`
- `lsof`
- `ss`
- `ip`
- `lsblk`
- `findmnt`
- `pacman`
- QEMU/KVM
- Serial console
- Emergency shell

### 18.2 Required test scenarios

- ISO boot in UEFI mode
- Installation on a clean virtual disk
- First boot
- Graphical login
- Wired and wireless networking
- Package update
- Interrupted update
- Encrypted storage unlocking
- Incorrect unlock password
- Low disk space
- GPU workload validation
- Rootless container execution
- VM creation and reset
- Network-isolation verification
- Snapshot restoration
- Fallback kernel boot
- Recovery after bootloader failure

Failures should be treated as learning opportunities and converted into automated regression tests.

---

## 19. Programming and Technical Skills Developed

### 19.1 Shell scripting

Shell scripting will be used for builds, installation, automation and system integration. Important concepts include:

- Quoting
- Exit codes
- Pipes
- Traps
- Idempotency
- Error handling
- Environment management

### 19.2 Python

Python is useful for installer logic, validation tools, package metadata processing, AI environments and automation.

### 19.3 C

C is valuable for learning system calls, memory, processes, signals, libraries, kernel interfaces and low-level debugging.

### 19.4 Rust

Rust is an optional but strong choice for new security-sensitive system utilities because it provides memory safety without requiring a garbage-collected runtime.

### 19.5 Qt/QML

QtQuick and QML will support custom panels, dashboards, overlays, launchers and animated desktop components.

### 19.6 Configuration formats

The project will use formats such as:

- Shell configuration
- `PKGBUILD`
- systemd unit files
- TOML
- YAML
- JSON
- QML
- Kernel configuration

New tools should be written only when existing Arch and Linux components cannot satisfy a clearly documented requirement.

---

## 20. What Will Be Learned

Developing this OS should teach:

- How Linux boots
- How distributions differ while using the same kernel
- How the kernel, firmware, userland and services interact
- How software becomes an Arch package
- How dependencies and upgrades break systems
- How package and source trust are established
- How to build and sign an ISO
- How to maintain a repository
- How GPU drivers and AI frameworks interact
- How to create reproducible AI environments
- How containers differ from virtual machines
- How to construct isolated security laboratories
- How to threat-model AI and conventional systems
- How hardware is exposed to userspace
- How services are supervised
- How to diagnose failures from logs and observable state
- How to design rollback and recovery
- How open-source licences affect redistribution
- How accessibility and animation affect interface engineering
- How architectural simplicity differs from merely installing fewer packages

The most valuable outcome will not be the ISO itself. It will be learning to make a complex system understandable, reproducible, secure and repairable.

---

## 21. Recommended Learning Progression

### Stage 1: System builder

Install Arch manually in a VM several times and configure it completely.

### Stage 2: Configuration designer

Move settings into version-controlled configuration and distribution packages.

### Stage 3: Image builder

Create a bootable ISO using `archiso`.

### Stage 4: Package maintainer

Build, test and sign packages and operate a small repository.

### Stage 5: Interface designer

Create the initial Hyprland and Quickshell experience, including accessible reduced-motion behaviour.

### Stage 6: AI platform engineer

Implement reproducible CPU, NVIDIA and AMD AI profiles and validate common workloads.

### Stage 7: Security engineer

Write the threat model and implement encryption, isolation, signed updates and secure recovery.

### Stage 8: Laboratory designer

Create disposable VM templates and isolated networks for conventional and AI red-teaming.

### Stage 9: Distribution maintainer

Automate ISO builds, installation testing, upgrades, rollbacks and releases.

### Stage 10: Systems programmer

Only after the foundation is dependable, consider custom system utilities, installer components, kernel patches or specialised security mechanisms.

---

## 22. Recommended First Release: Version 0.1

Version 0.1 should deliberately limit its scope to:

- Arch Linux `x86_64` base
- UEFI boot
- Standard Arch kernel
- LTS fallback kernel
- Hyprland desktop
- Small custom Quickshell interface
- PipeWire and desktop portals
- CPU, NVIDIA and AMD installation choices
- Rootless Podman
- One reproducible PyTorch and Jupyter environment
- Local inference through Ollama or llama.cpp
- QEMU/KVM red-team laboratory
- One Kali attacker VM template
- One vulnerable target VM template
- One AI-security environment with Garak and PyRIT
- Btrfs snapshots
- LUKS encryption
- Secure Boot investigation
- Custom configuration package
- Automated ISO build
- Automated VM boot and installation test
- Documented recovery process

### 22.1 Version 0.1 success criteria

The first release is successful when it can:

1. Build reproducibly enough to identify unintended differences.
2. Boot reliably in a UEFI virtual machine.
3. Install onto a clean virtual disk.
4. Reach a working animated desktop.
5. Launch an isolated AI environment.
6. Validate CPU or GPU-backed PyTorch operation.
7. Run a local model.
8. Launch an isolated security laboratory.
9. Run a basic AI red-team assessment against a local test target.
10. Update and recover through a documented rollback procedure.

---

## 23. Research Documents to Read

### 23.1 Linux and Unix foundations

1. **Arch Linux principles**  
   <https://wiki.archlinux.org/title/Arch_Linux>

2. **Arch Linux installation guide**  
   <https://wiki.archlinux.org/title/Installation_guide>

3. **Linux From Scratch**  
   <https://www.linuxfromscratch.org/lfs/>

4. **The Art of Unix Programming**  
   <http://www.catb.org/esr/writings/taoup/html/>

5. **POSIX.1 specification**  
   <https://pubs.opengroup.org/onlinepubs/9799919799/>

6. **Filesystem Hierarchy Standard 3.0**  
   <https://refspecs.linuxfoundation.org/FHS_3.0/index.html>

### 23.2 Arch distribution engineering

- PKGBUILD: <https://wiki.archlinux.org/title/PKGBUILD>
- Creating packages: <https://wiki.archlinux.org/title/Creating_packages>
- makepkg: <https://wiki.archlinux.org/title/Makepkg>
- pacman: <https://wiki.archlinux.org/title/Pacman>
- Clean chroot builds: <https://wiki.archlinux.org/title/DeveloperWiki:Building_in_a_clean_chroot>
- archiso: <https://wiki.archlinux.org/title/Archiso>
- Custom repository guidance: <https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#Custom_local_repository>
- Kernel compilation: <https://wiki.archlinux.org/title/Kernel/Traditional_compilation>

### 23.3 Boot and system architecture

- Arch boot process: <https://wiki.archlinux.org/title/Arch_boot_process>
- Unified Kernel Image: <https://wiki.archlinux.org/title/Unified_kernel_image>
- mkinitcpio: <https://wiki.archlinux.org/title/Mkinitcpio>
- systemd-boot: <https://wiki.archlinux.org/title/Systemd-boot>
- systemd project documentation: <https://systemd.io/>
- UEFI specifications: <https://uefi.org/specifications>

### 23.4 Security

- Arch security guidance: <https://wiki.archlinux.org/title/Security>
- Secure Boot: <https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot>
- dm-crypt and LUKS: <https://wiki.archlinux.org/title/Dm-crypt>
- Linux kernel security documentation: <https://www.kernel.org/doc/html/latest/security/>
- Linux Security Modules: <https://www.kernel.org/doc/html/latest/admin-guide/LSM/>
- Kernel self-protection: <https://www.kernel.org/doc/html/latest/security/self-protection.html>
- AppArmor: <https://wiki.archlinux.org/title/AppArmor>
- SELinux: <https://wiki.archlinux.org/title/SELinux>
- systemd execution and sandboxing: <https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html>
- CIS Benchmarks: <https://www.cisecurity.org/cis-benchmarks>
- NIST Secure Software Development Framework: <https://csrc.nist.gov/pubs/sp/800/218/final>

### 23.5 Supply-chain and release security

- Arch package signing: <https://wiki.archlinux.org/title/Pacman/Package_signing>
- GnuPG documentation: <https://www.gnupg.org/documentation/>
- Reproducible Builds: <https://reproducible-builds.org/docs/>
- SOURCE_DATE_EPOCH specification: <https://reproducible-builds.org/specs/source-date-epoch/>
- SLSA specification: <https://slsa.dev/spec/>
- The Update Framework: <https://theupdateframework.io/>
- Sigstore documentation: <https://docs.sigstore.dev/>

### 23.6 Desktop and interface

- Hyprland documentation: <https://wiki.hypr.land/>
- Quickshell: <https://quickshell.org/>
- Qt documentation: <https://doc.qt.io/>
- Wayland: <https://wayland.freedesktop.org/>
- PipeWire: <https://docs.pipewire.org/>

### 23.7 AI and GPU systems

- PyTorch local installation: <https://pytorch.org/get-started/locally/>
- Jupyter documentation: <https://docs.jupyter.org/>
- Ollama documentation: <https://docs.ollama.com/>
- NVIDIA CUDA installation guide: <https://docs.nvidia.com/cuda/cuda-installation-guide-linux/>
- NVIDIA Container Toolkit: <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html>
- AMD ROCm documentation: <https://rocm.docs.amd.com/>
- Podman: <https://podman.io/>

### 23.8 Virtualisation and isolation

- QEMU on Arch: <https://wiki.archlinux.org/title/QEMU>
- libvirt QEMU driver and security architecture: <https://libvirt.org/drvqemu.html>
- Qubes OS architecture: <https://doc.qubes-os.org/en/latest/developer/system/architecture.html>
- Qubes security design goals: <https://doc.qubes-os.org/en/latest/developer/system/security-design-goals.html>

### 23.9 Red-teaming and AI security

- Kali tools: <https://www.kali.org/tools/>
- Kali metapackages: <https://www.kali.org/docs/general-use/metapackages/>
- NVIDIA Garak: <https://github.com/NVIDIA/garak/>
- Microsoft PyRIT: <https://azure.github.io/PyRIT/>
- OWASP GenAI Security Project: <https://genai.owasp.org/>
- OWASP GenAI Red Teaming Guide: <https://genai.owasp.org/resource/genai-red-teaming-guide/>
- OWASP GenAI LLM Top 10 2026: <https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/>
- MITRE ATLAS repository: <https://github.com/mitre/advmlthreatmatrix>

---

## 24. Project Documents to Create Before Implementation

The following internal documents should guide development:

1. **Vision and non-goals** — identity, users, objectives and exclusions
2. **Unix philosophy interpretation** — concrete engineering rules
3. **Threat model** — assets, adversaries, attack surfaces and mitigations
4. **Architecture decision records** — documented technical choices and trade-offs
5. **Hardware support matrix** — CPUs, GPUs, networking and tested devices
6. **Package policy** — inclusion, exclusion, patching and replacement rules
7. **Trust and supply-chain model** — sources, signing, builds and key rotation
8. **AI environment specification** — runtime, GPU and reproducibility standards
9. **Red-team isolation specification** — VM, container and network boundaries
10. **Interface design system** — animation, colour, states and accessibility
11. **Update and rollback design** — releases, snapshots and recovery
12. **Installation specification** — storage, encryption and hardware detection
13. **Privacy model** — telemetry, logs, crash reports and network communication
14. **Testing strategy** — package, ISO, hardware, security and upgrade tests
15. **Recovery handbook** — boot, encryption, rollback and data recovery
16. **Licensing register** — upstream licences, firmware and redistribution duties

---

## 25. Principal Architectural Decision

The project's most important early decision is:

> Keep the host trusted and comprehensible; place rapidly changing AI dependencies in reproducible environments; place offensive tools and untrusted workloads in disposable, clearly identified security domains.

This structure makes it possible to combine an attractive daily-use workstation, a capable AI development platform and a serious red-team laboratory without allowing one function to undermine all the others.

---

## 26. Final Perspective

The best starting combination is:

- **ArchWiki** for implementation
- **Linux From Scratch** for understanding
- **Unix literature** for design discipline
- **A written threat model** for security
- **Containers and lockfiles** for AI reproducibility
- **Virtual machines and isolated networks** for red-teaming
- **Hyprland and Quickshell** for a distinctive interface
- **Automated builds and recovery tests** for maintainability

The long-term achievement is not simply a customised ISO. It is a system that makes advanced AI and security work powerful, visually inspiring, reproducible, isolated and recoverable.

