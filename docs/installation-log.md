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
- `screenshots/step3/network-pfsense.png`
- `screenshots/step3/network-kali.png`
- `screenshots/step3/network-debian.png`
- `screenshots/step3/network-msf2.png`

## Step 4: pfSense installation and configuration (2026-10-08)

**Done:**
- Booted pfSense VM from the installer ISO
- Accepted license, selected Install CE, chose ZFS for partitioning, rebooted
- Removed the ISO from the CD drive before the second boot
- Assigned interfaces via MAC address:
  - em0 (NAT) → WAN
  - em1 (intnet-attack) → LAN (ATTACK)
  - em2 (intnet-targets) → OPT1 (TARGETS)
- Configured interfaces in console menu (option 2):
  - LAN: 10.10.10.1/24, DHCP enabled (10.10.10.100 to 10.10.10.199)
  - OPT1: 10.10.20.1/24 (static, no DHCP)
- Accessed webConfigurator from Kali (https://10.10.10.1)
- Completed setup wizard:
  - Hostname: fw, Domain: lab.home.arpa
  - Timezone: Europe/Paris
  - WAN: DHCP
  - DNS: left empty (uses Unbound resolver)
- Configured DHCP static mapping:
  - Kali MAC address → 10.10.10.10, hostname: kali
- Configured DNS host overrides:
  - srv01.lab.home.arpa → 10.10.20.10
  - msf2.lab.home.arpa → 10.10.20.20
- Enabled "Block RFC1918 Private Networks" and "Block bogon networks" on WAN
- Verified DHCP leases show Kali correctly assigned to 10.10.10.10

**Problems and solutions:**
- Installation failed on first attempt: package fetch error from pkg.pfsense.org, retried installation, succeeded on second try
- After installation, pfSense booted into installer again instead of the system, ISO was still connected to the CD drive, Removed ISO from VirtualBox VM settings before rebooting, pfSense booted from disk correctly
- Initially configured LAN via DHCP in console menu, corrected to static IP 10.10.10.1/24 with DHCP server enabled

**Screenshots:**
- `screenshots/step4/pfsense-dashboard.png`
- `screenshots/step4/pfsense-dhcp-leases.png`
- `screenshots/step4/pfsense-interfaces.png`

**Next:** Configure Debian and Kali (steps 5-6).

## Step 5 & 6: Configuration of Debian and Kali (2026-10-08)

**Done:**
- Changed Kali's password
- Verified ip address
- Looked for updates
- Cloned the git repository with SSH
- Network config on Debian
- SSH hardening (administration from Kali)

**Screenshots:**
- `screenshots/step5/kali-ip.png`
