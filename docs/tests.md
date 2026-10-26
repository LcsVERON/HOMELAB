# Segmentation tests

This document proves that the firewall policy in
[03-firewall-rules.md](03-firewall-rules.md) actually works: allowed flows pass,
forbidden flows are blocked, and the firewall is what blocks them.

All 11 tests gave the expected result, and the automated script reported 0
failures.

## 1. Reading a result: blocked or closed?

A refused connection and a blocked connection look different. Knowing which is
which is how a test proves the firewall, and not just a missing service.

| Output of `nc -zv -w3 IP PORT` | Meaning |
|--------------------------------|---------|
| `succeeded` / `open` | Allowed, and a service is listening |
| `Connection refused` | The packet got through, but nothing is listening on that port |
| *timeout* (no answer) | Packet blocked: pfSense silently dropped it |

A *timeout* is the signature of a firewall block. A *refused* means the packet
reached the host, so the firewall let it through.

## 2. Test matrix

| # | From | Command | Expected | Actual | Rule |
|---|------|---------|----------|--------|------|
| T1 | Kali | `nmap -sn 10.10.20.0/24` | Debian and Metasploitable discovered | ✅ | ATTAQUE R1 |
| T2 | Kali | `nmap -sV 10.10.20.20` | Many vulnerable services | ✅ | ATTAQUE R1 |
| T3 | Kali | `curl -I http://10.10.20.10:4280/login.php` | `HTTP 200` (DVWA) | ✅ | ATTAQUE R1 |
| T4 | Kali | `curl -I https://www.debian.org` | OK (Internet reachable) | ✅ | ATTAQUE R3 |
| T5 | Kali | `nc -zv -w3 192.168.1.1 80` | *timeout* (private network blocked) | ✅ | ATTAQUE R4 |
| T6 | Debian | reach `deb.debian.org:80` | OK (updates reachable) | ✅ | CIBLES R4 |
| T7 | Debian | reach `10.10.10.10:22` | *timeout* (no pivot to ATTAQUE) | ✅ | CIBLES R7 |
| T8 | Debian | reach `10.10.20.1:443` | *timeout* (firewall admin blocked) | ✅ | CIBLES R6 |
| T9 | Metasploitable | `ping -c2 8.8.8.8` | fails (no Internet) | ✅ | CIBLES R7 |
| T10 | Metasploitable | `nc 10.10.10.10 4444` (Kali listening) | connection established | ✅ | CIBLES R5 |
| T11 | Metasploitable | `nc 10.10.10.10 5555` (Kali listening) | blocked, no connection | ✅ | CIBLES R7 |

Notes:

- **T5** targets a representative private address (192.168.1.1). Rule R4 blocks
  the whole RFC1918 range, so any private destination is dropped the same way;
  the home network is unreachable as a consequence of being private.
- **T6, T7, T8** are driven from Kali over SSH by `check-lab.sh`, so they run in
  the same pass as the Kali-side checks.

## 3. Automated test script

Run from Kali: [../scripts/check-lab.sh](../scripts/check-lab.sh). It checks all
the Kali-side and Debian-side flows in one pass.

```bash
chmod +x scripts/check-lab.sh
./scripts/check-lab.sh 192.168.1.1
```

Output:

```
=== From Kali (LAN_ATTACK) ===
[PASS] ATTACK gateway (10.10.10.1)
[PASS] DNS resolution
[PASS] Internet HTTPS
[PASS] Debian SSH (22)
[PASS] Debian nginx (80)
[PASS] DVWA (4280)
[PASS] Metasploitable FTP (21)
[PASS] Metasploitable SMB (445)
[PASS] Home network blocked (192.168.1.1)
[PASS] Target discovery: Debian up
[PASS] Target discovery: Metasploitable up
=== From Debian (LAN_TARGETS), over SSH ===
[PASS] Debian updates reachable (80)
[PASS] Debian cannot pivot to Kali (22)
[PASS] Debian cannot reach FW admin (443)
----
Result: 14 passed, 0 failed
```

## 4. T2: version scan of Metasploitable

From Kali, `nmap -sV 10.10.20.20` confirms the target exposes many old,
vulnerable services. This proves the attacker can reach and fingerprint the
target, while the target-side tests (T7-T11) stay blocked.

```
PORT     STATE SERVICE      VERSION
21/tcp   open  ftp          vsftpd 2.3.4
22/tcp   open  ssh          OpenSSH 4.7p1 Debian 8ubuntu1 (protocol 2.0)
23/tcp   open  telnet
25/tcp   open  smtp         Postfix smtpd
53/tcp   open  domain       ISC BIND 9.4.2
80/tcp   open  http         Apache httpd 2.2.8 ((Ubuntu) DAV/2)
111/tcp  open  rpcbind      2 (RPC #100000)
139/tcp  open  netbios-ssn  Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
445/tcp  open  netbios-ssn  Samba smbd 3.X - 4.X (workgroup: WORKGROUP)
512/tcp  open  exec         netkit-rsh rexecd
513/tcp  open  login
514/tcp  open  shell        Netkit rshd
1099/tcp open  java-rmi     GNU Classpath grmiregistry
1524/tcp open  bindshell    Metasploitable root shell
2049/tcp open  nfs          2-4 (RPC #100003)
3306/tcp open  mysql        MySQL 5.0.51a-3ubuntu5
5432/tcp open  postgresql   PostgreSQL DB 8.3.0 - 8.3.7
5900/tcp open  vnc          VNC (protocol 3.3)
6000/tcp open  X11          (access denied)
6667/tcp open  irc          UnrealIRCd
8180/tcp open  http         Apache Tomcat/Coyote JSP engine 1.1
(scan completed in ~201 s)
```

## 5. T9-T11: target-side tests

These three are run by hand because they start from Metasploitable, and the
reverse-shell tests need a listener on Kali at the same time.

**T9 - Metasploitable has no Internet.** On Metasploitable:

```
msfadmin@metasploitable:~$ ping -c2 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
--- 8.8.8.8 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 1073ms
```

Blocked by R7: targets have no route to the Internet.

**T10 - reverse shell allowed on 4444.** Kali listens, Metasploitable connects.
On Kali:

```
$ nc -lvnp 4444
listening on [any] 4444 ...
connect to [10.10.10.10] from (UNKNOWN) [10.10.20.20] 52720
```

The connection is established: rule R5 allows a new connection from a target to
Kali on the reverse-shell port range. This is the subtle case, because the
connection is initiated by the target, not by Kali.

**T11 - reverse shell blocked on 5555.** Same setup, port outside the range.
On Kali:

```
$ nc -lvnp 5555
listening on [any] 5555 ...
```

Kali never sees a connection: port 5555 is outside the 4444-4450 range, so R7
blocks it. This proves the reverse-shell opening is tightly scoped.

## 6. Firewall log evidence

Each blocked test was confirmed in *Status > System Logs > Firewall*. Every
dropped packet appears as a red entry with its source, destination and the rule
that blocked it, which proves the firewall is what blocks the flow.

- `screenshots/step9/t9-msf-no-internet.png` — T9: Metasploitable (10.10.20.20)
  pinging 8.8.8.8, blocked on CIBLES by the default-deny rule. The target has no
  route to the Internet.
- `screenshots/step9/t11-reverse-blocked.png` — T11: Metasploitable to
  10.10.10.10:5555, blocked on CIBLES. The port is outside the reverse-shell
  range (4444-4450), so it is dropped.
- `screenshots/step9/t5-home-blocked.png` — T5: Kali (10.10.10.10) to a private
  address on port 80, blocked on ATTAQUE by the explicit default-deny rule. The
  lab cannot reach a private network outside itself.
- `screenshots/step9/t10-reverse-shell.png` — T10: the allowed reverse shell, Kali
  listening on 4444 and receiving the connection from Metasploitable
  (10.10.20.20). This is the allowed counterpart of T11.

## 7. Summary

All 11 tests gave the expected result. Allowed flows work: the attacker reaches
and fingerprints the targets (T1-T3), both lab zones reach the Internet where
intended (T4, T6), and a reverse shell returns to Kali on the allowed port (T10).
Forbidden flows are blocked: the private network is unreachable from the lab
(T5), targets cannot pivot to the attacker or administer the firewall (T7, T8),
the vulnerable target has no Internet (T9), and a reverse shell outside the
allowed range is dropped (T11). The automated script reports 14 passed, 0 failed.

## Tests added in step 10

| # | From | Command | Expected | Actual | Rule |
|---|------|---------|----------|--------|------|
| T12 | Metasploitable | `ping -c2 10.10.30.1` | OK (gateway reachable) | ✅ | VULN R1 |
| T13 | Metasploitable | `ping -c2 10.10.20.10` | fails (cannot reach Debian) | ✅ | VULN R4 |
| T14 | Kali | `nc -zv -w3 10.10.30.20 21` | OK (can still attack Metasploitable) | ✅ | ATTAQUE -> VULN |
| T15 | Kali (attack) | open `https://10.10.10.1` | blocked (no admin from attack zone) | ✅ | ATTAQUE (anti-lockout removed) |
| T16 | Kali (mgmt) | open `https://10.10.99.1` | OK (admin from MGMT) | ✅ | MGMT R1 |

T13 is the proof that the documented limitation is closed: Metasploitable can no
longer reach Debian, and the drop appears in the firewall log on VULN.

**802.1Q proof.** On Kali, capturing the trunk interface shows the VLAN 99 tag:

```
$ sudo tcpdump -i eth1 -e -n vlan
... 802.1Q, ... vlan 99, p 0, ethertype IPv4, 10.10.99.10 > 10.10.99.1: ICMP echo request
```

Screenshots: `screenshots/step10/msf-to-debian-blocked.png` (T13), `screenshots/step10/tcpdump-vlan99.png`
(VLAN 99 tag), `screenshots/step10/rules-vuln.png`, `screenshots/step10/rules-mgmt.png`, `screenshots/step10/rules-attaque.png`.