#!/usr/bin/env bash
# check-lab.sh: verifies allowed and blocked flows across the lab.
# Run from Kali (LAN_ATTACK). Debian-side checks are driven over SSH.
# Usage: ./check-lab.sh [ROUTER_IP]
#   ROUTER_IP: gateway of the host's real network (home router), default 192.168.1.1

ROUTER_IP="${1:-192.168.1.1}"
DEB_USER="vboxuser"
DEB_IP="10.10.20.10"
MSF_IP="10.10.20.20"
KALI_IP="10.10.10.10"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"

pass=0; fail=0

check() {  # check "description" ok|ko command...
    local desc="$1" expected="$2"; shift 2
    if "$@" >/dev/null 2>&1; then got=ok; else got=ko; fi
    if [ "$got" = "$expected" ]; then
        echo "[PASS] $desc"; pass=$((pass + 1))
    else
        echo "[FAIL] $desc (expected: $expected, got: $got)"; fail=$((fail + 1))
    fi
}

echo "=== From Kali (LAN_ATTACK) ==="
check "ATTACK gateway (10.10.10.1)"           ok ping -c1 -W2 10.10.10.1
check "DNS resolution"                        ok getent hosts deb.debian.org
check "Internet HTTPS"                        ok curl -sf -o /dev/null -m5 https://deb.debian.org
check "Debian SSH (22)"                       ok nc -z -w3 "$DEB_IP" 22
check "Debian nginx (80)"                     ok nc -z -w3 "$DEB_IP" 80
check "DVWA (4280)"                           ok curl -sf -o /dev/null -m5 "http://$DEB_IP:4280/login.php"
check "Metasploitable FTP (21)"               ok nc -z -w3 "$MSF_IP" 21
check "Metasploitable SMB (445)"              ok nc -z -w3 "$MSF_IP" 445
check "Home network blocked ($ROUTER_IP)"     ko nc -z -w3 "$ROUTER_IP" 80

# T1: both targets must be discovered
if command -v nmap >/dev/null 2>&1; then
    hosts=$(nmap -sn -n 10.10.20.0/24 2>/dev/null)
    check "Target discovery: Debian up"           ok grep -q "$DEB_IP" <<<"$hosts"
    check "Target discovery: Metasploitable up"   ok grep -q "$MSF_IP" <<<"$hosts"
fi

echo "=== From Debian (LAN_TARGETS), over SSH ==="
if ssh $SSH_OPTS "$DEB_USER@$DEB_IP" true >/dev/null 2>&1; then
    check "Debian updates reachable (80)"     ok ssh $SSH_OPTS "$DEB_USER@$DEB_IP" "timeout 3 bash -c 'echo > /dev/tcp/deb.debian.org/80'"
    check "Debian cannot pivot to Kali (22)"  ko ssh $SSH_OPTS "$DEB_USER@$DEB_IP" "timeout 3 bash -c 'echo > /dev/tcp/$KALI_IP/22'"
    check "Debian cannot reach FW admin (443)" ko ssh $SSH_OPTS "$DEB_USER@$DEB_IP" "timeout 5 bash -c 'echo > /dev/tcp/10.10.20.1/443'"
else
    echo "[SKIP] Debian SSH not available, skipping target-side checks"
fi

echo "----"
echo "Result: $pass passed, $fail failed"
echo
echo "Manual tests (two machines or Metasploitable's console, see docs/05-tests.md):"
echo "  T9  - Metasploitable has no Internet:  ping -c2 8.8.8.8  (must fail)"
echo "  T10 - reverse shell allowed (4444):    Kali 'nc -lvnp 4444' + Meta 'nc $KALI_IP 4444'"
echo "  T11 - reverse shell blocked (5555):    Kali 'nc -lvnp 5555' + Meta 'nc $KALI_IP 5555'  (must time out)"
[ "$fail" -eq 0 ]