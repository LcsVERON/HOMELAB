# Installation log

Chronological record of what was done at each step, the problems met and how
they were solved. One section per step of the project, newest at the bottom.

Rules for this file:

- No passwords, tokens or private keys, ever.
- Public IP addresses and real MAC addresses of the host are not recorded.
- A problem is only useful with its cause and its fix.

---

## Step 1: preparation (2026-09-28)

**Done:**
- Checked virtualization support (VT-x / AMD-V enabled in the BIOS).
- Chose the hypervisor: VirtualBox 7.2.20 on Windows 11 Pro.
- Downloaded from official sources: pfSense CE installer, Kali Linux image, Debian 13 amd64 netinst, Metasploitable 2.
- Verified the SHA-256 checksum of every image.

**Problems and solutions:**
- none

---

## Step 2: GitHub repository (2026-09-28)

**Done:**
- Created the public `homelab` repository and cloned it on the host.
- Added `.gitignore`, temporary `README.md` and `docs/architecture.md`.

**Problems and solutions:**
- none

---

## Step 3: hypervisor and virtual networks (2026-09-29)

**Done:**
- Wrote the addressing plan: [addressing-plan.md](addressing-plan.md).
- Created the two internal networks:
  - `intnet-attack` (VLAN 10, LAN_ATTACK)
  - `intnet-targets` (VLAN 20, LAN_TARGETS)
- Created the 4 VMs without starting them: pfSense, Kali, Debian, Metasploitable 2.
- Attached network adapters as documented in `configs/virtualbox/vm-networks.md`.
- Set Promiscuous Mode to *Allow VMs* on every internal network adapter.
- Verified Metasploitable 2 has only one adapter on `intnet-targets` (no NAT, no bridge).
- Noted the MAC address of each pfSense adapter.
- Drafted the network diagram: `diagrams/homelab.drawio`.

**Problems and solutions:**
- It was a bit difficult to use Virtual Box as I was not used to it, so I looked for help on the Internet and I was assisted by AI.

**Screenshots:**
- `screenshots/network-pfsense.png`
- `screenshots/network-kali.png`
- `screenshots/network-debian.png`
- `screenshots/network-msf2.png`
