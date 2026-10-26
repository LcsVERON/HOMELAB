# VirtualBox: VM network settings

Hypervisor: VirtualBox 7.2.20 on Windows 11 Pro.

In VirtualBox, an **internal network** is an isolated virtual switch: only the
VMs attached to it can talk to each other, and the host has no access to it.
Two internal networks with different names are two separate broadcast domains,
which is how the lab emulates VLAN 10 and VLAN 20.

## Internal networks

| Name | Emulates | Subnet | Attached VMs |
|------|----------|--------|--------------|
| `intnet-attack` | VLAN 10 (LAN_ATTACK) | 10.10.10.0/24 | pfSense (adapter 2), Kali |
| `intnet-targets` | VLAN 20 (LAN_TARGETS) | 10.10.20.0/24 | pfSense (adapter 3), Debian, Metasploitable 2 |

Names are case-sensitive: a VM attached to `Intnet-attack` would be alone on
its own switch.

## Network adapters per VM

| VM | Adapter 1 | Adapter 2 | Adapter 3 |
|----|-----------|-----------|-----------|
| pfSense | **NAT** (WAN, gets 10.0.2.15 by DHCP) | Internal network `intnet-attack` | Internal network `intnet-targets` |
| Kali | Internal network `intnet-attack` | - | - |
| Debian | Internal network `intnet-targets` | - | - |
| Metasploitable 2 | Internal network `intnet-targets` | - | - |

Settings applied to **every internal network adapter**
(*Settings > Network > Adapter N > Advanced*):

| Setting | Value | Why |
|---------|-------|-----|
| Adapter type | Intel PRO/1000 MT Desktop (82540EM) | Default; shows up as `em0`/`em1`/`em2` in pfSense. Metasploitable 2 may need *PCnet-FAST III* if it gets no link |
| Promiscuous mode | **Allow VMs** | Lets pfSense and Kali see frames not addressed to them (routing, packet captures) |
| Cable connected | ticked | - |

## pfSense interface mapping

Recorded so that interfaces can be assigned correctly at first boot
(pfSense identifies them by MAC address).

| VirtualBox adapter | Attached to | MAC address | pfSense interface | Role |
|--------------------|-------------|-------------|-------------------|------|
| Adapter 1 | NAT | 08002725E565 | `em0` | WAN |
| Adapter 2 | `intnet-attack` | 0800273E9E52 | `em1` | LAN (ATTACK), 10.10.10.1/24 |
| Adapter 3 | `intnet-targets` | 080027AE13BB | `em2` | OPT1 (TARGETS), 10.10.20.1/24 |

## VM sizing

| VM | Type | vCPU | RAM | Disk | Notes |
|----|------|------|-----|------|-------|
| pfSense | BSD / FreeBSD (64-bit) | 1 | 1 GB | 16 GB | Boots from pfSense CE installer ISO; NAT adapter must have Internet access during installation |
| Kali | Linux / Debian (64-bit) | 2 | 2 to 4 GB | as shipped | Imported from official VirtualBox image |
| Debian 13 | Linux / Debian (64-bit) | 1 | 1 to 2 GB | 20 GB | netinst ISO, no desktop environment |
| Metasploitable 2 | Linux / Ubuntu (32-bit) | 1 | 512 MB | existing `Metasploitable.vmdk` | Imported disk, do not convert |

## Safety rules

- **Metasploitable 2 is never attached to a NAT, NAT Network or Bridged adapter.** Its only adapter is on `intnet-targets`, so it can only be reached through pfSense.
- Only pfSense has a NAT adapter. No other VM has a direct path to the host or to the home network.
- Bridged mode is not used anywhere in the lab.

## Changes in step 10: VLAN trunk and new zones

A third internal network was added to carry the two new zones over a single 802.1Q trunk.

| Name | Role | Attached VMs |
|------|------|--------------|
| `intnet-trunk` | 802.1Q trunk: native VLAN = VULN, tagged VLAN 99 = MGMT | pfSense (adapter 4), Metasploitable (untagged = VULN), Kali (adapter 2, tagged VLAN 99 = MGMT) |

Updated adapters:

| VM | Change |
|----|--------|
| pfSense | Adapter 4 added, internal network `intnet-trunk`, promiscuous "Allow VMs". Appears as em3, used as a trunk (native VULN + tagged VLAN 99) |
| Metasploitable 2 | Adapter moved from `intnet-targets` to `intnet-trunk` (untagged), IP changed to 10.10.30.20 |
| Kali | Adapter 2 added, internal network `intnet-trunk`, promiscuous "Allow VMs". Appears as eth1; a tagged VLAN 99 sub-interface (eth1.99) carries management |

Every internal-network adapter keeps promiscuous mode "Allow VMs".