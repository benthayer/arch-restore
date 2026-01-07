#!/bin/bash
# Auto-partition script for Arch install
# Layout: [root p1] [swap p99] [efi p100]
# Root first = can expand by shrinking swap from front
set -e

# =============================================================================
# FIND LARGEST DISK
# =============================================================================

find_largest_disk() {
  lsblk -dnbo NAME,SIZE,TYPE | awk '$3=="disk" {print $2, $1}' | sort -rn | head -1 | awk '{print $2}'
}

bytes_to_human() {
  local bytes=$1
  if (( bytes >= 1099511627776 )); then
    echo "$(( bytes / 1099511627776 ))TB"
  elif (( bytes >= 1073741824 )); then
    echo "$(( bytes / 1073741824 ))GB"
  else
    echo "$(( bytes / 1048576 ))MB"
  fi
}

get_disk_size_bytes() {
  lsblk -dnbo SIZE "/dev/$1" 2>/dev/null
}

# =============================================================================
# MAIN
# =============================================================================

DISK=$(find_largest_disk)
DISK_SIZE=$(get_disk_size_bytes "$DISK")
DISK_HUMAN=$(bytes_to_human "$DISK_SIZE")

echo ""
echo "Found largest disk: /dev/$DISK ($DISK_HUMAN)"
echo ""

# Get partition sizes
read -p "EFI size [256M]: " EFI_SIZE
EFI_SIZE=${EFI_SIZE:-256M}

read -p "Swap size [8G]: " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-8G}

# Calculate root size (display only - it gets the rest)
# Parse sizes to bytes for display
parse_size() {
  local size=$1
  local num=${size%[GMKgmk]*}
  local unit=${size##*[0-9]}
  case ${unit^^} in
    G) echo $(( num * 1073741824 )) ;;
    M) echo $(( num * 1048576 )) ;;
    K) echo $(( num * 1024 )) ;;
    *) echo "$num" ;;
  esac
}

EFI_BYTES=$(parse_size "$EFI_SIZE")
SWAP_BYTES=$(parse_size "$SWAP_SIZE")
ROOT_BYTES=$(( DISK_SIZE - EFI_BYTES - SWAP_BYTES - 1048576 ))  # 1MB for GPT overhead
ROOT_HUMAN=$(bytes_to_human "$ROOT_BYTES")

# Determine partition naming
if [[ "$DISK" == nvme* ]]; then
  P="p"  # nvme0n1p1
else
  P=""   # sda1
fi

PART_ROOT="/dev/${DISK}${P}1"
PART_SWAP="/dev/${DISK}${P}99"
PART_EFI="/dev/${DISK}${P}100"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  PARTITION PLAN: /dev/$DISK"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Physical layout on disk:"
echo "  [root p1: $ROOT_HUMAN] [swap p99: $SWAP_SIZE] [efi p100: $EFI_SIZE]"
echo ""
echo "  $PART_ROOT   $ROOT_HUMAN   Linux filesystem (ext4)"
echo "  $PART_SWAP   $SWAP_SIZE       Linux swap"
echo "  $PART_EFI  $EFI_SIZE      EFI System (FAT32)"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  ⚠️  THIS WILL DESTROY ALL DATA ON /dev/$DISK"
echo ""
read -p "  Continue? [y/N]: " CONFIRM

if [[ "${CONFIRM,,}" != "y" ]]; then
  echo "Aborted."
  exit 1
fi

echo ""
echo "Partitioning /dev/$DISK..."

# Wipe and create GPT
sgdisk --zap-all "/dev/$DISK"

# Create partitions in physical order with specific partition numbers
# p1 = root (first on disk, uses remaining space)
# p99 = swap (middle)
# p100 = EFI (last on disk)

# Calculate sector positions (512-byte sectors)
SECTOR_SIZE=512
EFI_SECTORS=$(( EFI_BYTES / SECTOR_SIZE ))
SWAP_SECTORS=$(( SWAP_BYTES / SECTOR_SIZE ))

# Get total sectors
TOTAL_SECTORS=$(( DISK_SIZE / SECTOR_SIZE ))

# Layout from end of disk backwards:
# Last 34 sectors reserved for backup GPT
# EFI at the end
# Swap before EFI
# Root from sector 2048 to before swap

EFI_END=$(( TOTAL_SECTORS - 34 ))
EFI_START=$(( EFI_END - EFI_SECTORS + 1 ))

SWAP_END=$(( EFI_START - 1 ))
SWAP_START=$(( SWAP_END - SWAP_SECTORS + 1 ))

ROOT_START=2048  # Standard alignment
ROOT_END=$(( SWAP_START - 1 ))

# Create partitions with explicit numbers
sgdisk -n 1:${ROOT_START}:${ROOT_END} -t 1:8300 -c 1:"Linux root" "/dev/$DISK"
sgdisk -n 99:${SWAP_START}:${SWAP_END} -t 99:8200 -c 99:"Linux swap" "/dev/$DISK"
sgdisk -n 100:${EFI_START}:${EFI_END} -t 100:ef00 -c 100:"EFI System" "/dev/$DISK"

# Reload partition table
partprobe "/dev/$DISK"
sleep 1

echo ""
echo "Formatting partitions..."

mkfs.ext4 -F "$PART_ROOT"
mkswap "$PART_SWAP"
mkfs.fat -F32 "$PART_EFI"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  DONE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Now run:"
echo "  ./install.sh $PART_EFI $PART_SWAP $PART_ROOT"
echo ""

