# Addressing plan

This document describes how IP addresses, VLAN IDs and DNS names are assigned
in the lab. It is the reference for every configuration file in `configs/` and
for the firewall rules in [firewall-rules.md](firewall-rules.md).

## 1. Networks

| Network | VLAN | Subnet | Gateway (pfSense) | DHCP | Purpose |
|---------|------|--------|-------------------|------|---------|
| WAN | - | DHCP (e.g. 10.0.2.15 with VirtualBox NAT) | provided by the NAT / home router | client | Internet access for pfSense and, through NAT, for the zones that are allowed out |
| LAN_ATTACK | 10 | 10.10.10.0/24 | 10.10.10.1 | 10.10.10.100 to 10.10.10.199 | Attacker workstation |
| LAN_TARGETS | 20 | 10.10.20.0/24 | 10.10.20.1 | none (static IPs only) | Server and intentionally vulnerable machines |

The pfSense firewall is the **only** path between these networks. Traffic
between two machines on the same subnet (Debian and Metasploitable, both in
LAN_TARGETS) does not cross pfSense and is therefore not filtered. This is a
known limitation, documented in [architecture.md](architecture.md).

## 2. Machines

| Machine | DNS name | Interface | IP address | Mode | Network |
|---------|----------|-----------|------------|------|---------|
| pfSense (WAN side) | fw.lab.home.arpa | WAN (`em0`) | DHCP | client | WAN |
| pfSense (ATTACK side) | fw.lab.home.arpa | LAN (`em1`) | 10.10.10.1/24 | static | LAN_ATTACK |
| pfSense (TARGETS side) | fw.lab.home.arpa | OPT1 (`em2`) | 10.10.20.1/24 | static | LAN_TARGETS |
| Kali Linux | kali.lab.home.arpa | eth0 | 10.10.10.10 | DHCP with static mapping | LAN_ATTACK |
| Debian 13 (srv01) | srv01.lab.home.arpa | enp0s3 | 10.10.20.10/24 | static | LAN_TARGETS |
| Metasploitable 2 | msf2.lab.home.arpa | eth0 | 10.10.20.20/24 | static | LAN_TARGETS |

## 3. Conventions inside a /24

| Range | Use | Example |
|-------|-----|---------|
| `.1` | Gateway (pfSense interface) | 10.10.20.1 |
| `.10` to `.99` | Static addresses (servers, targets, reserved attacker IP) | 10.10.20.10, 10.10.20.20 |
| `.100` to `.199` | DHCP pool | 10.10.10.100 to 10.10.10.199 |
| `.200` to `.254` | Reserved for future use (extra VMs, appliances) | - |

Static hosts are numbered in steps of 10 (`.10`, `.20`, `.30`) so that new
machines can be inserted without renumbering.

## 4. Why these choices

- **10.10.0.0/16 (RFC 1918).** The range is private, so nothing in the lab is
  routable on the Internet. It also avoids collisions with home routers, which
  almost always use 192.168.0.0/24 or 192.168.1.0/24.
- **Third octet = VLAN ID.** 10.10.**10**.x is VLAN **10**, 10.10.**20**.x is
  VLAN **20**. Any IP seen in a log, a capture or a rule immediately tells which
  zone it belongs to.
- **One subnet per security zone.** A zone is a broadcast domain. Two zones
  are only connected through pfSense, so every inter-zone flow is filtered and
  can be logged.
- **No DHCP in LAN_TARGETS.** Targets have fixed addresses so that firewall
  rules and test scripts can reference them reliably.
- **DHCP with a static mapping for Kali.** Kali keeps the convenience of
  DHCP (gateway, DNS pushed by pfSense) but always receives 10.10.10.10, because
  the reverse-shell firewall rule targets that exact address.
- **`lab.home.arpa` domain.** `home.arpa` is reserved by RFC 8375 for
  residential networks and is never resolved on the public Internet.

## 5. DHCP and DNS on pfSense

> Completed in step 4, once pfSense is installed.

### DHCP server (ATTACK interface)

| Setting | Value |
|---------|-------|
| Range | 10.10.10.100 to 10.10.10.199 |
| Gateway / DNS pushed to clients | 10.10.10.1 |
| Domain | lab.home.arpa |

**Static mappings**

| Hostname | MAC address | IP address |
|----------|-------------|------------|
| kali | `<Kali MAC address>` | 10.10.10.10 |

### DNS resolver (Unbound), host overrides

| Host | Domain | IP address |
|------|--------|------------|
| srv01 | lab.home.arpa | 10.10.20.10 |
| msf2 | lab.home.arpa | 10.10.20.20 |
| kali | lab.home.arpa | 10.10.10.10 |