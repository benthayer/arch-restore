#!/bin/bash
# Arch Linux Base System Recovery
# Usage: ./install.sh /dev/nvme0n1p1 /dev/nvme0n1p2
#                     boot-partition  root-partition
set -e

# =============================================================================
# SEMANTIC ATOMS
# =============================================================================

BOOT_PARTITION=$1
ROOT_PARTITION=$2

BASE_SYSTEM="base linux linux-firmware"
MICROCODE="amd-ucode intel-ucode"
NETWORK="networkmanager"
BOOTABLE_DESKTOP="i3 xorg-server xorg-xinit sddm"
MINIMAL_TOOLS="zsh git vim"
FIRST_BROWSER="firefox"
FIRST_TERMINAL="terminator"

PACSTRAP_PACKAGES="$BASE_SYSTEM $MICROCODE $NETWORK $BOOTABLE_DESKTOP $MINIMAL_TOOLS $FIRST_BROWSER $FIRST_TERMINAL"

HOSTNAME="arch"
USERNAME="ben"
DEFAULT_PASSWORD="changeme"
TIMEZONE="America/New_York"
NEW_ROOT="/mnt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_KEY="$SCRIPT_DIR/deploy_key"
PERSONALIZATION_REPO="git@github.com:benthayer/arch-personalization.git"
BACKGROUNDS_REPO="git@github.com:benthayer/backgrounds.git"

# =============================================================================
# FUNCTIONS
# =============================================================================

validate_args() {
  if [[ -z "$BOOT_PARTITION" || -z "$ROOT_PARTITION" ]]; then
    echo "Usage: $0 <boot-partition> <root-partition>"
    echo "Example: $0 /dev/nvme0n1p1 /dev/nvme0n1p2"
    exit 1
  fi
}

setup_deploy_key() {
  echo ""
  echo "=== Personalization Setup ==="
  echo "Enter deploy key passphrase to enable automatic cloning."
  echo "Press Enter with no passphrase to skip (manual clone later)."
  echo ""
  
  eval "$(ssh-agent -s)"
  
  if ssh-add "$DEPLOY_KEY" 2>/dev/null; then
    CLONE_ENABLED=true
    echo "Deploy key loaded. Repos will be cloned automatically."
  else
    CLONE_ENABLED=false
    echo "Skipping automatic clone. You'll need to clone manually after reboot."
  fi
}

clone_personalization_repos() {
  if [[ "$CLONE_ENABLED" != true ]]; then
    return
  fi
  
  local USER_HOME="$NEW_ROOT/home/$USERNAME"
  
  echo "Cloning arch-personalization..."
  git clone "$PERSONALIZATION_REPO" "$USER_HOME/.ben"
  
  echo "Adding backgrounds key..."
  ssh-add "$USER_HOME/.ben/keys/backgrounds_deploy_key"
  
  echo "Cloning backgrounds..."
  mkdir -p "$USER_HOME/files/Pictures"
  git clone "$BACKGROUNDS_REPO" "$USER_HOME/files/Pictures/Backgrounds"
  
  echo "Creating configure.sh symlink..."
  ln -sf ".ben/setup/configure.sh" "$USER_HOME/configure.sh"
  
  echo "Fixing ownership..."
  arch-chroot $NEW_ROOT chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
}

confirm_destructive_operation() {
  echo "Installing to: boot=$BOOT_PARTITION, root=$ROOT_PARTITION"
  echo "This will FORMAT these partitions. Press Enter to continue or Ctrl+C to abort."
  read -r
}

format_partitions() {
  mkfs.fat -F32 "$BOOT_PARTITION"
  mkfs.ext4 -F "$ROOT_PARTITION"
}

mount_partitions() {
  mount "$ROOT_PARTITION" $NEW_ROOT
  mkdir -p $NEW_ROOT/boot
  mount "$BOOT_PARTITION" $NEW_ROOT/boot
}

install_base_system() {
  pacstrap $NEW_ROOT $PACSTRAP_PACKAGES
}

generate_fstab() {
  genfstab -U $NEW_ROOT >> $NEW_ROOT/etc/fstab
}

configure_locale() {
  echo "en_US.UTF-8 UTF-8" > $NEW_ROOT/etc/locale.gen
  arch-chroot $NEW_ROOT locale-gen
}

configure_timezone() {
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" $NEW_ROOT/etc/localtime
}

configure_hostname() {
  echo "$HOSTNAME" > $NEW_ROOT/etc/hostname
}

create_user() {
  useradd -R $NEW_ROOT -m -G wheel -s /bin/zsh "$USERNAME"
  echo "$USERNAME:$DEFAULT_PASSWORD" | chpasswd -R $NEW_ROOT
  echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> $NEW_ROOT/etc/sudoers
}

enable_essential_services() {
  systemctl --root=$NEW_ROOT enable NetworkManager sddm
}

install_systemd_boot() {
  mkdir -p $NEW_ROOT/boot/EFI/BOOT $NEW_ROOT/boot/loader/entries
  cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi $NEW_ROOT/boot/EFI/BOOT/BOOTX64.EFI
  create_loader_config
  create_arch_boot_entry
}

create_loader_config() {
  cat > $NEW_ROOT/boot/loader/loader.conf << EOF
default arch.conf
timeout 3
EOF
}

create_arch_boot_entry() {
  cat > $NEW_ROOT/boot/loader/entries/arch.conf << EOF
title Arch Linux
linux /vmlinuz-linux
initrd /amd-ucode.img
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=$ROOT_PARTITION rw
EOF
}

generate_initramfs() {
  arch-chroot $NEW_ROOT mkinitcpio -P
}

unmount_all() {
  umount -R $NEW_ROOT
}

print_success() {
  echo ""
  echo "=========================================="
  echo "Done. Base system installed."
  echo "Reboot and login as '$USERNAME' with password '$DEFAULT_PASSWORD'"
  echo ""
  if [[ "$CLONE_ENABLED" == true ]]; then
    echo "Personalization repos cloned. Run:"
    echo "  ~/configure.sh"
  else
    echo "Then run personalization:"
    echo "  git clone git@github.com:benthayer/arch-personalization.git ~/.ben"
    echo "  ~/.ben/setup/configure.sh"
  fi
  echo "=========================================="
}

# =============================================================================
# MAIN
# =============================================================================

validate_args
setup_deploy_key
confirm_destructive_operation

# Phase 1: Prepare disk
format_partitions
mount_partitions

# Phase 2: Install system
install_base_system
generate_fstab

# Phase 3: Configure system
configure_locale
configure_timezone
configure_hostname
create_user
enable_essential_services

# Phase 4: Make bootable
install_systemd_boot
generate_initramfs

# Phase 5: Personalization (if key was provided)
clone_personalization_repos

# Done
unmount_all
print_success
