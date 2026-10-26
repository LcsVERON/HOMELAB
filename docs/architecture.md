# Architecture

## Hardware and hypervisor
- Host machine: laptop with AMD Ryzen 5 7535U (6 cores / 12 threads, AMD-V enabled),
  16 GB RAM, 512 GB NVMe SSD (KIOXIA, ≈ 330 GB free), Windows 11 Pro
- Hypervisor: Oracle VirtualBox 7.2.20
- RAM budget: pfSense 1 GB + Kali 4 GB + Debian 2 GB + Metasploitable 0.5 GB ≈ 7.5 GB,
  leaving enough memory for Windows
- Why this choice:
  - Proxmox VE was considered, but it needs a dedicated machine and I did not have
    a spare computer available, so VirtualBox on my everyday laptop was the practical option
  - Free and well documented, with a large community
  - Snapshots make it easy to reset vulnerable machines to a clean state after each exercise
  - Internal networks create isolated segments that the host and the home network
    cannot reach, which keeps the vulnerable machines contained
  - Enough resources on this laptop to run all four VMs at once
  - Limitation: no real 802.1Q VLAN tagging (each segment is a separate internal network);
    moving to Proxmox VE on dedicated hardware is a possible next step (resolved in step 10, see below)

## Security zones

| Zone | Role | Internet access |
|------|------|-----------------|
| WAN | Way out to the Internet (VirtualBox NAT) | - |
| LAN_ATTACK | Attacker workstation (Kali) | Yes (updates, tools) |
| LAN_TARGETS | Debian server + vulnerable machines | Debian: updates only. Metasploitable: never |

An intentionally vulnerable machine must never be reachable from the
home network or from the Internet. pfSense is the only path between zones.

## Technical choices
- pfSense CE: firewall, routing, NAT, DHCP and DNS in one place
- Addressing 10.10.X.0/24, X = VLAN number
- lab.home.arpa domain (RFC 8375)

## Known limitations (resolved in step 10, see below)

- **Debian ↔ Metasploitable traffic is not filtered.** Both are in CIBLES, on
  the same subnet, so their traffic never crosses pfSense. If Metasploitable is
  compromised, it can reach Debian directly. Fix planned in future work: a
  separate VLAN for vulnerable machines, so pfSense filters that traffic too.
- **Kali can administer pfSense**, via the anti-lockout rule and via 10.10.20.1
  through R1. In a real network, administration would come from a dedicated
  management VLAN, and the anti-lockout rule would be removed from the attacker
  zone.
- **R6 overlaps with R7.** R7 already blocks everything, including the firewall.
  R6 is kept on purpose: it gives a dedicated log line for attempts against the
  firewall, and it protects against a permissive rule being added later between
  the two.

## Improvements implemented (step 10)

Two new security zones were added, carried by an 802.1Q trunk on a 4th pfSense
interface (em3):

| Zone | Subnet | VLAN | Role |
|------|--------|------|------|
| VULN | 10.10.30.0/24 | native on the trunk | Vulnerable targets (Metasploitable) |
| MGMT | 10.10.99.0/24 | tagged VLAN 99 | Firewall administration only |

**1. Metasploitable isolated (closed limitation).** Metasploitable moved from
CIBLES to VULN. Debian and Metasploitable are now in different subnets, so their
traffic crosses pfSense and is filtered. The limitation "Debian and
Metasploitable traffic is not filtered", listed above, is now closed. A compromised Metasploitable can no longer reach Debian directly.

**2. Real 802.1Q VLAN.** MGMT is a tagged VLAN (99) on the em3 trunk; Kali tags
it on a dedicated sub-interface. VULN uses the native (untagged) VLAN of the same
trunk, because Metasploitable is too old to tag its own frames. This is a
realistic trunk carrying a native VLAN plus a tagged VLAN.

**3. Management plane separated.** pfSense is now administered only from MGMT
(10.10.99.1). The anti-lockout rule was removed from ATTAQUE, so the attack zone
can no longer reach the firewall admin. This applies least privilege: the attack
machine has no rights over the firewall.

**Honest limitations of this version.**
- The MGMT machine is a second interface on Kali, not a separate host. If Kali
  is fully compromised, both planes fall. In production the admin plane would be
  a dedicated machine. The architecture (admin only from MGMT) is correct; only
  the admin host is shared, for lack of a separate VM.
- VULN uses the native VLAN rather than a tagged one, because of Metasploitable's
  age.
