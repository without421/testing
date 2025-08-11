mount /dev/sda3 /mnt
mount /dev/sda1 /mnt/boot/efi

arch-chroot /mnt /bin/bash <<'EOF'
set -e  # Arrêter en cas d'erreur

# === PURGE COMPLÈTE ===
echo "1. Purge des anciens chargeurs..."
rm -rf /boot/efi/EFI/*
echo " - Tous les fichiers EFI supprimés"

# Purge des entrées UEFI
echo "2. Purge des entrées UEFI..."
while read -r bootnum; do
    [ -n "$bootnum" ] && efibootmgr -b "$bootnum" -B
done < <(efibootmgr | grep -Eo 'Boot[0-9A-F]{4}' | cut -c5-)
echo " - Toutes les entrées UEFI supprimées"

# Détection automatique des paramètres
EFI_PARTITION=$(findmnt /boot/efi -n -o SOURCE)
DISK_PATH=$(readlink -f /dev/disk/by-path/* | grep $(basename $EFI_PARTITION) | head -1)
ROOT_UUID=$(blkid -s UUID -o value $(findmnt / -n -o SOURCE))

# Réinstallation
grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=GRUB \
    --boot-directory=/boot \
    --recheck \
    --debug

# === CONFIGURATION FALLBACK ===
echo "4. Configuration du fallback..."
mkdir -p /boot/efi/EFI/BOOT
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

# === CONFIGURATION GRUB ===
echo "5. Configuration GRUB..."
echo "GRUB_CMDLINE_LINUX=\"root=UUID=$ROOT_UUID rw\"" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# === VÉRIFICATIONS FINALES ===
echo "6. Vérifications finales..."
echo " - Structure EFI:"
tree -L 2 /boot/efi/EFI
echo " - Entrées UEFI:"
efibootmgr -v
echo " - UUID root: $ROOT_UUID"
echo " - Fichier GRUB:"
grep menuentry /boot/grub/grub.cfg | head -n 5
EOF

umount -R /mnt
reboot
