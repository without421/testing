{
# Mount partitions
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot/efi

# Enter chroot environment
arch-chroot /mnt /bin/bash <<'EOF'
# Fix bootloader files
echo "===== REBUILDING BOOTLOADER FILES ====="
bootctl install --path=/boot/efi
mkdir -p /boot/efi/EFI/BOOT
cp /usr/lib/systemd/boot/efi/systemd-bootx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

# Create valid boot entry
echo "===== CREATING CORRECT BOOT ENTRY ====="
ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
cat > /boot/loader/entries/arch.conf <<CONF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$ROOT_UUID rw
CONF

# Install missing firmware
echo "===== INSTALLING MISSING FIRMWARE ====="
pacman -Sy --noconfirm \
    linux-firmware \
    upd72020x-fw \
    wd719x-firmware \
    aic94xx-firmware \
    qlogic-firmware \
    sbsigntools

# Sign GRUB EFI file
echo "===== SIGNING GRUB EFI ====="
mkdir -p /etc/secureboot/keys
cd /etc/secureboot/keys
openssl req -newkey rsa:4096 -nodes -keyout db.key \
    -new -x509 -sha256 -days 3650 -subj "/CN=Arch SB Key/" -out db.crt
sbsign --key db.key --cert db.crt \
    --output /boot/efi/EFI/GRUB/grubx64.efi.signed \
    /boot/efi/EFI/GRUB/grubx64.efi
mv /boot/efi/EFI/GRUB/grubx64.efi.signed /boot/efi/EFI/GRUB/grubx64.efi

# Final verification
echo "===== FINAL SYSTEM STATUS ====="
ls -l /boot/efi/EFI/{BOOT,GRUB,systemd}
echo -e "\n===== BOOT ENTRY CONTENTS ====="
cat /boot/loader/entries/arch.conf
echo -e "\n===== SECURE BOOT STATUS ====="
[ -d /sys/firmware/efi/efivars ] && \
    od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-* | head -c1 | \
    awk '{print ($1 == 1) ? "ENABLED" : "DISABLED"}'
EOF

# Cleanup and output
echo "===== OPERATION COMPLETE ====="
echo "1. Firmware installed"
echo "2. GRUB signed"
echo "3. Bootloader reconfigured"
} | tee >(nc termbin.com 9999)
