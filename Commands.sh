#!/bin/bash

# Error handling: Exit immediately if any command fails
set -e

# Mount partitions
echo "===== MOUNTING PARTITIONS ====="
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot/efi

# Run diagnostics
echo "===== RUNNING DIAGNOSTICS ====="
arch-chroot /mnt bash -c '
echo -e "\n===== SYSTEM DIAGNOSTICS =====" > /diagnostics.txt
date >> /diagnostics.txt

echo -e "\n===== UEFI BOOT ENTRIES =====" >> /diagnostics.txt
efibootmgr -v 2>>/diagnostics.txt

echo -e "\n===== BOOTLOADER FILES =====" >> /diagnostics.txt
ls -lR /boot 2>>/diagnostics.txt

echo -e "\n===== JOURNAL LOGS =====" >> /diagnostics.txt
journalctl -b -1 --no-pager 2>>/diagnostics.txt | head -n 100

echo -e "\n===== KERNEL ERRORS =====" >> /diagnostics.txt
dmesg -T -l err,alert,emerg 2>>/diagnostics.txt

echo -e "\n===== FSTAB CONTENT =====" >> /diagnostics.txt
cat /etc/fstab 2>>/diagnostics.txt

echo -e "\n===== SECURE BOOT STATUS =====" >> /diagnostics.txt
mokutil --sb-state 2>>/diagnostics.txt
'

# Install missing firmware
echo "===== INSTALLING FIRMWARE ====="
arch-chroot /mnt bash -c '
pacman -Sy --noconfirm \
    linux-firmware \
    upd72020x-fw \
    wd719x-firmware \
    aic94xx-firmware \
    qlogic-firmware \
    sbsigntools
mkinitcpio -P
'

# Sign GRUB EFI
echo "===== SIGNING GRUB ====="
arch-chroot /mnt bash -c '
mkdir -p /etc/secureboot/keys
cd /etc/secureboot/keys

if [ ! -f db.key ]; then
    openssl req -newkey rsa:4096 -nodes -keyout db.key \
        -new -x509 -sha256 -days 3650 -subj "/CN=Arch Secure Boot Key/" -out db.crt
fi

sbsign --key db.key --cert db.crt \
    --output /boot/efi/EFI/GRUB/grubx64.efi.signed \
    /boot/efi/EFI/GRUB/grubx64.efi

mv /boot/efi/EFI/GRUB/grubx64.efi.signed /boot/efi/EFI/GRUB/grubx64.efi
'

# Generate shareable diagnostic URL
echo "===== GENERATING SHARE URL ====="
curl --upload-file /mnt/diagnostics.txt https://transfer.sh/arch_diagnostics.txt

# Final reboot preparation
echo "===== OPERATION COMPLETE ====="
echo "1. Diagnostics URL: (see above)"
echo "2. Unmount and reboot:"
echo "   umount -R /mnt"
echo "   reboot"
