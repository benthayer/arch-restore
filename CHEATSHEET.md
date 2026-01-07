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
# Find your disk
lsblk

# Partition it (example: /dev/nvme0n1)
fdisk /dev/nvme0n1
```

Inside fdisk:
```
g        # new GPT partition table

n        # new partition 1 (boot)
         # enter for default partition number
         # enter for default first sector
+256M    # 256MB for boot
t        # change type
1        # EFI System

n        # new partition 2 (swap)
         # enter for default partition number
         # enter for default first sector
+8G      # 8GB for swap (adjust to your RAM)
t        # change type
2        # select partition 2
19       # Linux swap

n        # new partition 3 (root)
         # enter for defaults (uses rest of disk)
         # enter
         # enter

w        # write and exit
```

Result: `/dev/nvme0n1p1` (boot), `/dev/nvme0n1p2` (swap), `/dev/nvme0n1p3` (root)

## 4. Install

```bash
./install.sh /dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3
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

