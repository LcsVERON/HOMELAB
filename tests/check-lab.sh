#!/usr/bin/env bash
# check-lab.sh: checks allowed and blocked flows from Kali (LAN_ATTACK)
# Usage: ./check-lab.sh [ROUTER_IP]

ROUTER_IP="${1:-192.168.1.1}"
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

check "ATTACK gateway (10.10.10.1)"          ok ping -c1 -W2 10.10.10.1
check "DNS resolution"                       ok getent hosts deb.debian.org
check "Internet HTTPS"                       ok curl -sf -o /dev/null -m5 https://deb.debian.org
check "Debian SSH (22)"                      ok nc -z -w3 10.10.20.10 22
check "Debian nginx (80)"                    ok nc -z -w3 10.10.20.10 80
check "DVWA (4280)"                          ok curl -sf -o /dev/null -m5 http://10.10.20.10:4280/login.php
check "Metasploitable FTP (21)"              ok nc -z -w3 10.10.20.20 21
check "Metasploitable SMB (445)"             ok nc -z -w3 10.10.20.20 445
check "Home network blocked ($ROUTER_IP)"    ko nc -z -w3 "$ROUTER_IP" 80

echo "----"
echo "Result: $pass passed, $fail failed"
[ "$fail" -eq 0 ]