# Firewall rules

This document describes and justifies every pfSense firewall rule in the lab.

Interface names in pfSense: **ATTAQUE** is the LAN side (10.10.10.0/24, the
attacker zone), **CIBLES** is the OPT1 side (10.10.20.0/24, the targets zone).

## 1. How pfSense filtering works

A few principles are needed to read the tables below.

- **Rules are evaluated on the interface where a packet enters.** A packet sent
  by Kali enters pfSense through ATTAQUE, so the ATTAQUE rule list decides its
  fate, whatever its destination. A packet sent by Debian enters through CIBLES.
- **Rules are read top to bottom, and the first match wins.** Precise "pass"
  rules go at the top, the general "block" rule goes at the bottom.
- **Anything not explicitly allowed is blocked (default deny).** A fresh
  interface with no rule drops everything that enters it. Adding a rule always
  means opening a specific path.
- **pfSense is stateful.** When a connection is allowed, pfSense records it in a
  state table and lets the reply packets back automatically. The return rule is
  therefore never written. This matters most for the reverse-shell rule (R5).
- **Traffic between two hosts on the same subnet is not filtered.** Debian and
  Metasploitable are both in CIBLES, so their traffic crosses the virtual switch
  directly, never pfSense. This is a known limitation.

Two pfSense terms used below:

- **"ATTAQUE/CIBLES subnets"** = the whole subnet (10.10.10.0/24 or 10.10.20.0/24).
- **"ATTAQUE/CIBLES address"** = only pfSense's own address on that interface
  (10.10.10.1 or 10.10.20.1).

## 2. Aliases

Aliases are names given to addresses or ports, so that rules stay readable and a
value is changed in one place. Created in *Firewall > Aliases*.

| Name | Type | Content | Purpose |
|------|------|---------|---------|
| `RFC1918` | Network | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | All private ranges. Used inverted to mean "the Internet, but no private network" (home network, VirtualBox NAT, other lab zones) |
| `KALI` | Host | `10.10.10.10` | Attacker workstation. Target of the reverse-shell rule, which is why Kali needs a fixed address |
| `SRV_DEBIAN` | Host | `10.10.20.10` | Debian server. Used as the source of the DNS, NTP and update rules, so those rights are granted to Debian only |
| `MSF2` | Host | `10.10.20.20` | Metasploitable 2. Not used by any current rule; kept for log filtering and future work |
| `PORTS_WEB` | Port | `80`, `443` | HTTP and HTTPS, for apt repositories and Docker images |
| `PORTS_REVERSE` | Port | `4444:4450` | Reverse-shell listening ports on Kali (4444 is Metasploit's default) |

## 3. ATTAQUE interface rules

These control what the attacker (Kali) is allowed to do.

| # | Action | Proto | Source | Destination | Port | Log | Justification |
|---|--------|-------|--------|-------------|------|-----|---------------|
| anti-lockout | Pass | TCP | any | ATTAQUE address | 80, 443 | - | Created automatically by pfSense. Keeps access to the web admin interface from this LAN, so you cannot lock yourself out while editing rules |
| R1 | Pass | any | ATTAQUE subnets | CIBLES subnets | any | ☑ | The whole point of the lab: Kali must be able to scan and attack every target, including DVWA on port 4280. Stateful, so replies return without a rule |
| R2 | Pass | TCP/UDP | ATTAQUE subnets | ATTAQUE address | 53 | - | DNS resolution through the pfSense Unbound resolver. Needed because 10.10.10.1 is private and R3 only allows public addresses |
| R2b | Pass | ICMP echo request | ATTAQUE subnets | ATTAQUE address | - | - | Ping the gateway for troubleshooting; the connectivity test in `check-lab.sh` depends on it |
| R3 | Pass | any | ATTAQUE subnets | **!** `RFC1918` (inverted) | any | - | Internet access for updates and tools, but no access to any private network (home network, VirtualBox NAT, other lab zones) |
| R4 | Block | any (IPv4+IPv6) | any | any | any | ☑ | Explicit, logged default deny. Same effect as the implicit deny, but makes every block visible in the logs. It produces the log entry that proves the home network is unreachable (test T5) |

After creating R1 to R4, the two automatic rules **"Default allow LAN to any"**
(IPv4 and IPv6) were deleted: they allowed everything, including the home
network. The anti-lockout rule was kept.

## 4. CIBLES interface rules

These control what the targets are allowed to do. This is the most important
list, because a target is assumed to be compromised at any time.

| # | Action | Proto | Source | Destination | Port | Log | Justification |
|---|--------|-------|--------|-------------|------|-----|---------------|
| R1 | Pass | ICMP echo request | CIBLES subnets | CIBLES address | - | - | Targets can ping their gateway, for troubleshooting |
| R2 | Pass | TCP/UDP | `SRV_DEBIAN` | CIBLES address | 53 | - | DNS for Debian only. Metasploitable has no DNS, which prevents data exfiltration hidden in DNS queries (DNS tunneling) |
| R3 | Pass | UDP | `SRV_DEBIAN` | CIBLES address | 123 | - | NTP time sync with pfSense. A correct clock is needed for consistent logs, TLS certificate checks and package validation. Debian must be pointed at 10.10.20.1 in `timesyncd.conf` |
| R4 | Pass | TCP | `SRV_DEBIAN` | **!** `RFC1918` | `PORTS_WEB` | ☑ | apt updates and Docker images, over HTTP/HTTPS only. Debian can do nothing else on the Internet and cannot reach the home network |
| R5 | Pass | TCP | CIBLES subnets | `KALI` | `PORTS_REVERSE` | ☑ | Allows reverse shells back to Kali. See the explanation below. Narrow, logged port range, Kali only |
| R6 | Block | any (IPv4+IPv6) | CIBLES subnets | This Firewall | any | ☑ | A compromised target must never reach the firewall's own interfaces or its admin. R1-R3 above still let ping, DNS and NTP through |
| R7 | Block | any (IPv4+IPv6) | CIBLES subnets | any | any | ☑ | Explicit, logged default deny: no Internet for Metasploitable, no pivot to ATTAQUE or to the home network |

A temporary **"CIBLES net → any → pass"** rule was used during Debian's
installation to allow package downloads, then deleted once nginx, Docker and
DVWA were installed.

### Why the reverse-shell rule (R5) is needed

In a reverse shell, the compromised machine opens the connection *towards* the
attacker, instead of the attacker connecting in. It is therefore a **new
connection initiated by the target**, entering pfSense through CIBLES. The state
table does not know it, because it is not the reply to a connection Kali opened.
Without R5, rule R7 would block it, and the exploit would fail even though the
vulnerability was successfully triggered.

R5 opens that path on purpose, but keeps it tight: destination Kali only, a
narrow port range (4444-4450), and every connection logged. Filtering what
*leaves* a zone, not only what enters it, is called egress filtering, and it is
the main defense against reverse shells. Test T11 checks that a reverse shell on
a port outside the range (5555) is blocked.

## 5. WAN interface

No inbound rules: everything arriving from the Internet or the home network is
blocked by default. The following settings are verified rather than created.

- **No rule in Firewall > Rules > WAN.** Replies to connections opened by Kali
  or Debian still return, thanks to the state table.
- **Interfaces > WAN**: "Block private networks and loopback addresses" and 
"Block bogon networks" both ticked.** The first drops WAN packets that claim a
  private source address; the second drops packets from unallocated Internet
  ranges. Both are common spoofing sources.
- **Firewall > NAT > Outbound: Automatic mode.** The lab's private 10.10.x.x
  addresses cannot travel on the Internet, so pfSense rewrites them to its WAN
  address on the way out. Automatic mode generates the needed rules per subnet.