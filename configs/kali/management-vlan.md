# Kali management interface (VLAN 99)

Kali reaches the pfSense admin interface only through the management VLAN.
A second VirtualBox adapter on `intnet-trunk` (eth1) carries a tagged VLAN 99 sub-interface, created as a persistent NetworkManager connection:

```
    sudo nmcli connection add type vlan con-name vlan99 dev eth1 id 99 ip4 10.10.99.10/24
```
```
    sudo nmcli connection up vlan99
```

No gateway is set on this interface: 10.10.99.1 is directly connected, and Kali keeps its default route via eth0. Administration is done at https://10.10.99.1.