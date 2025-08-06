{
# Mount partitions
mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot/efi

# Enter chroot environment
arch-chroot /mnt /bin/bash <<'EOF'
# Enable maximum debugging
echo "===== ENABLING DIAGNOSTICS ====="
echo 'kernel.printk=7 4 1 7' > /etc/sysctl.d/99-verbose-kernel.conf
echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7 debug systemd.log_level=debug systemd.log_target=kmsg initcall_debug"' >> /etc/default/grub
echo 'GRUB_CMDLINE_LINUX=""' >> /etc/default/grub

# Install GRUB and dependencies
echo "===== INSTALLING GRUB ====="
pacman -Sy --noconfirm \
    grub \
    efibootmgr \
    os-prober \
    sbsigntools \
    linux-firmware \
    upd72020x-fw \
    wd719x-firmware \
    aic94xx-firmware \
    qlogic-firmware

# Configure GRUB
echo "===== CONFIGURING GRUB ====="
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --debug
grub-mkconfig -o /boot/grub/grub.cfg

# Sign GRUB components
echo "===== SIGNING GRUB ====="
mkdir -p /etc/secureboot/keys
cd /etc/secureboot/keys
openssl req -newkey rsa:4096 -nodes -keyout db.key \
    -new -x509 -sha256 -days 3650 -subj "/CN=Arch SB Key/" -out db.crt

# Sign all GRUB EFI files
find /boot/efi/EFI/GRUB -type f -name "*.efi" | while read -r efi_file; do
    echo "Signing $efi_file"
    sbsign --key db.key --cert db.crt --output "$efi_file.signed" "$efi_file"
    mv "$efi_file.signed" "$efi_file"
done

# Create fallback bootloader
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

# Enable boot tracing
echo "===== ENABLING BOOT TRACING ====="
echo 'GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=true
GRUB_DISABLE_SUBMENU=y
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7 debug systemd.log_level=debug systemd.log_target=kmsg initcall_debug trace trace_event=*"
GRUB_GFXMODE=auto
GRUB_RECORDFAIL_TIMEOUT=30' > /etc/default/grub

# Reconfigure GRUB with tracing
grub-mkconfig -o /boot/grub/grub.cfg

# Final diagnostics
echo "===== SYSTEM DIAGNOSTICS ====="
echo -e "\nBOOT FILES:"
ls -lR /boot
echo -e "\nGRUB CONFIG:"
cat /boot/grub/grub.cfg | head -n 100
echo -e "\nEFI BOOT ENTRIES:"
efibootmgr -v
echo -e "\nSECURE BOOT STATUS:"
mokutil --sb-state 2>/dev/null || echo "Secure Boot: Disabled (mokutil not found)"
echo -e "\nKERNEL PARAMS:"
cat /proc/cmdline
echo -e "\nBLKID:"
blkid
echo -e "\nFSTAB:"
cat /etc/fstab
EOF

# Collect BIOS/UEFI diagnostics
echo "===== FIRMWARE DIAGNOSTICS ====="
dmesg | grep -i 'efi\|acpi'
dmidecode -t bios

# Final steps
echo "===== OPERATION COMPLETE ====="
echo "1. GRUB installed and signed"
echo "2. Full boot tracing enabled"
echo "3. System diagnostics captured"
echo "After reboot, capture early boot messages with:"
echo "  journalctl -b -k -p debug | nc termbin.com 9999"
} | tee >(nc termbin.com 9999)
