#!/bin/bash
# Build custom Arch ISO with arch-restore baked in
set -e

ISO_NAME="arch-restore"
WORK_DIR="/tmp/archiso-build"
OUT_DIR="$(pwd)/out"

# Ensure archiso is installed
if ! command -v mkarchiso &>/dev/null; then
  echo "Installing archiso..."
  sudo pacman -S --needed --noconfirm archiso
fi

# Clean previous builds
sudo rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

# Copy the releng profile (standard Arch live ISO)
cp -r /usr/share/archiso/configs/releng/* "$WORK_DIR/"

# Add arch-restore repo to the ISO
AIROOTFS="$WORK_DIR/airootfs"
mkdir -p "$AIROOTFS/root/arch-restore"

echo "Copying arch-restore into ISO..."
cp -r ./* "$AIROOTFS/root/arch-restore/" 2>/dev/null || true
rm -rf "$AIROOTFS/root/arch-restore/out"  # don't include built ISOs

# Create wifi symlink for easy access
mkdir -p "$AIROOTFS/usr/local/bin"
ln -sf /root/arch-restore/wifi "$AIROOTFS/usr/local/bin/wifi"

# Add welcome message
cat >> "$AIROOTFS/root/.zshrc" << 'EOF'

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           ARCH RESTORE - Recovery Environment             ║"
echo "╠═══════════════════════════════════════════════════════════╣"
echo "║  1. Connect WiFi:    wifi                                 ║"
echo "║  2. Partition disk:  fdisk /dev/nvme0n1                   ║"
echo "║  3. Install:         cd arch-restore && ./install.sh      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
EOF

# Also add to bash in case zsh isn't default
cp "$AIROOTFS/root/.zshrc" "$AIROOTFS/root/.bashrc" 2>/dev/null || true

echo "Building ISO..."
sudo mkarchiso -v -w "$WORK_DIR/work" -o "$OUT_DIR" "$WORK_DIR"

echo ""
echo "=========================================="
echo "ISO built: $OUT_DIR/archlinux-*.iso"
echo "Upload to GitHub Releases or copy to USB"
echo "=========================================="

