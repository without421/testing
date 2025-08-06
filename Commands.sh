{ 
# Error handling
set -e

# Mount partitions
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot/efi

# Diagnostic collection
echo "===== SYSTEM DIAGNOSTICS ====="
date
echo -e "\n===== UEFI BOOT ENTRIES ====="
efibootmgr -v || echo "efibootmgr not available"
echo -e "\n===== BOOTLOADER FILES ====="
ls -lR /boot
echo -e "\n===== FSTAB CONTENT ====="
cat /etc/fstab
echo -e "\n===== SECURE BOOT STATUS ====="
[ -d /sys/firmware/efi/efivars ] && \
  od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* | head -c1 | \
  awk '{print ($1 == 1) ? "ENABLED" : "DISABLED"}'

# Install missing components
echo -e "\n===== INSTALLING FIRMWARE ====="
pacman -Sy --noconfirm \
    linux-firmware \
    upd72020x-fw \
    wd719x-firmware \
    aic94xx-firmware \
    qlogic-firmware \
    sbsigntools

# Sign GRUB
echo -e "\n===== SIGNING GRUB ====="
mkdir -p /etc/secureboot/keys
cd /etc/secureboot/keys
openssl req -newkey rsa:4096 -nodes -keyout db.key \
    -new -x509 -sha256 -days 3650 -subj "/CN=Arch SB Key/" -out db.crt
sbsign --key db.key --cert db.crt \
    --output /boot/efi/EFI/GRUB/grubx64.efi.signed \
    /boot/efi/EFI/GRUB/grubx64.efi
mv /boot/efi/EFI/GRUB/grubx64.efi.signed /boot/efi/EFI/GRUB/grubx64.efi

# Final status
echo -e "\n===== OPERATION COMPLETE ====="
echo "Firmware installed and GRUB signed successfully!"
} | tee /tmp/diag.log | nc termbin.com 9999
