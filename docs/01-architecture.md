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
    moving to Proxmox VE on dedicated hardware is a possible next step

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

## Known limitations
<to be completed in step 8>

## Future work
<to be completed in step 10>
