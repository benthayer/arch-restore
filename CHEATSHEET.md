# Recovery Cheat Sheet

## 1. WiFi

```bash
iwctl
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "YourNetwork"
# enter password when prompted
exit
```

Verify: `ping google.com`

## 2. Get This Repo

```bash
pacman -Sy git
git clone https://github.com/benthayer/arch-restore.git
cd arch-restore
```

## 3. Partition

```bash
./partition.sh
# Auto-detects largest disk
# Prompts for EFI size (default 256M)
# Prompts for swap size (default 8G)
# Shows plan, confirms, formats
```

Layout: `[root p1] [swap p99] [efi p100]`
Root first = can expand later by shrinking swap.

Result (NVMe): `p1` (root), `p99` (swap), `p100` (efi)

## 4. Install

```bash
# partition.sh tells you the exact command, e.g.:
./install.sh /dev/nvme0n1p100 /dev/nvme0n1p99 /dev/nvme0n1p1
# enter deploy key passphrase when prompted
```

## 5. After Reboot

```bash
# Connect WiFi (now with NetworkManager)
nmcli device wifi connect "YourNetwork" password "YourPassword"

# Run configure
~/configure.sh
```

Done.

