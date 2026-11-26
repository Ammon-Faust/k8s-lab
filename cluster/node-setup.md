# Node Setup

How the three lab nodes were prepared before installing k3s.

## Hardware and OS

| Item | Details |
|------|---------|
| Machine | Lenovo ThinkCentre M710q (model MT 10MR) x3 |
| CPU | Intel Core i5-7500T @ 2.70GHz |
| RAM | 16GB (2x 8GB, dual channel) |
| Disk | 256GB NVMe (`nvme0n1`) |
| OS | Ubuntu Server 24.04.5 LTS (default server install, not minimized) |

The installer ISO's SHA256 checksum was verified against the value published
on the Ubuntu release page before writing the USB stick (Rufus, ISO mode).

## Node inventory

| Hostname | IP | Interface | User |
|----------|----|-----------|------|
| k8s-1 | 192.168.1.11 | wlp2s0 | sre |
| k8s-2 | 192.168.1.12 | wlp2s0 | sre |
| k8s-3 | 192.168.1.13 | wlp2s0 | sre |

IPs are DHCP reservations on the router, not static settings on the machines.

## Networking

The nodes are on Wi-Fi for now (no Ethernet available yet). Ubuntu Server has
no Wi-Fi tooling out of the box, so `wpasupplicant` had to be installed first,
which needed a temporary connection (see "Problems I hit" below).

Wi-Fi is configured with netplan in `/etc/netplan/01-wifi.yaml`. Redacted
example:

```yaml
network:
  version: 2
  wifis:
    wlp2s0:
      dhcp4: true
      access-points:
        "SSID":
          password: "Password"
```

The real file contains the Wi-Fi password, so it is never committed. It is
locked down with `sudo chmod 600 /etc/netplan/01-wifi.yaml`, and changes are
tested with `sudo netplan try`, which rolls back automatically if
connectivity breaks.

A second file, `/etc/netplan/02-wired.yaml`, matches any `en*` interface with
DHCP and `optional: true`. It was added for USB phone tethering and will also
pick up a wired adapter later.

**Planned:** move the nodes to wired Ethernet for more stablity.
etcd is sensitive to latency and jitter, and Wi-Fi can cause leader elections.

### DHCP reservations

Set on the Netgear Nighthawk router under
**Advanced > Setup > LAN Setup > Address Reservation**. Reserve each node's IP
using the MAC address of its Wi-Fi interface (the `link/ether` value under the
`wlp2s0` entry in `ip a`).

- [x] k8s-1 reserved as 192.168.1.11
- [x] k8s-2 reserved as 192.168.1.12
- [x] k8s-3 reserved as 192.168.1.13

## Post-install checklist

Done on each node:

- [x] Ubuntu Server 24.04.5 installed, ISO checksum verified
- [x] OpenSSH server installed
- [x] `wpasupplicant` installed and Wi-Fi connected
- [x] `sudo apt update && sudo apt full-upgrade`, then reboot once and confirm
      the node comes back on Wi-Fi by itself
- [x] Confirm time sync (`timedatectl`)

Still to do on each node:

- [ ] SSH key login from WSL (`ssh-copy-id`), then confirm login works
- [ ] Router DHCP reservations set (above)
- [ ] Decide memory swap on or off (on by default)
- [ ] Check whether a firewall is active, and which ports k3s needs open
      between nodes

## Access

- SSH: `ssh sre@<node-ip>` from WSL, using key-based login.
- kubectl: TODO once k3s is installed (where the kubeconfig comes from and
  what address it points to). The kubeconfig is never committed.

## Problems I hit and how I fixed them

### 1. Wi-Fi would not start: `netplan-wpa-wlp2s0.service` dependency failed

- **Symptom:** `sudo netplan try` failed with "A dependency job for
  netplan-wpa-wlp2s0.service failed". The interface showed as off in
  `networkctl`.
- **Cause:** `wpa_supplicant` was not installed (`which wpa_supplicant`
  printed nothing), and netplan needs it for Wi-Fi.
- **Fix:** get a temporary connection, install `wpasupplicant`, then retry.

### 2. No network to install the package

- **Symptom:** the package needed a connection, and Wi-Fi was the thing being
  set up.
- **Fix:** USB tethering from a phone. The tether interface appeared in
  `ip a` but had no address until it was given a netplan config.

## Reset procedure

TODO: how to wipe a node and start over (the k3s uninstall scripts and
anything they leave behind), once k3s is installed and the reset has been
practiced.

