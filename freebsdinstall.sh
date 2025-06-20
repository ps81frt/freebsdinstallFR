#!/bin/sh

###############################################################################
# TUTORIEL DE CONNEXION RÉSEAU (si non détecté automatiquement)
#
# Ethernet :
#     dhclient <interface>
#     ex: dhclient em0
#
# Wi-Fi :
#     ifconfig wlan0 up
#     ifconfig wlan0 scan
#     vi /etc/wpa_supplicant.conf
#         network={
#             ssid="MonSSID"
#             psk="MonMotDePasse"
#         }
#     wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
#     dhclient wlan0
###############################################################################

set -e

### === Fonctions === ###

choisir_langue() {
    echo "=== Choix de la langue ==="
    echo "1) Français"
    echo "2) Anglais"
    read -p "Choix [1-2]: " choix
    [ "$choix" = "1" ] && export LANG=fr_FR.UTF-8 || export LANG=en_US.UTF-8
}

detecter_disques() {
    echo "=== Disques disponibles ==="
    sysctl -n kern.disks
    read -p "Disque cible (ex: ada0, da0): " disk
    [ ! -e "/dev/${disk}" ] && echo "Disque introuvable" && exit 1
}

choisir_mode_boot() {
    echo "=== Mode de démarrage ==="
    echo "1) UEFI"
    echo "2) BIOS (Legacy)"
    read -p "Choix [1-2]: " boot_mode
}

choisir_partitionnement() {
    echo "=== Partitionnement ==="
    echo "1) Automatique (ZFS)"
    echo "2) Manuel"
    read -p "Choix [1-2]: " part_mode
}

partitionner_disque_auto() {
    echo "Suppression et création des partitions..."
    read -p "Confirmez l'effacement du disque $disk (yes pour continuer) : " confirm
    [ "$confirm" != "yes" ] && exit 1

    gpart destroy -F "$disk" >/dev/null 2>&1 || true
    gpart create -s gpt "$disk"

    if [ "$boot_mode" = "1" ]; then
        gpart add -a 1M -s 512M -t efi "$disk"
        newfs_msdos /dev/${disk}p1
        mkdir -p /mnt/boot/efi
        mount -t msdosfs /dev/${disk}p1 /mnt/boot/efi
    else
        gpart add -a 4k -s 512k -t freebsd-boot "$disk"
        gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 "$disk"
    fi

    gpart add -a 1M -s 2G -t freebsd-swap "$disk"
    gpart add -a 1M -t freebsd-zfs "$disk"

    zpool create -f -o altroot=/mnt -O compress=lz4 -O atime=off -O mountpoint=/ zroot /dev/${disk}p3
    zfs create -o mountpoint=/ zroot/ROOT
    zfs create -o mountpoint=/tmp -o setuid=off zroot/tmp
    zfs create -o mountpoint=/usr zroot/usr
    zfs create -o mountpoint=/var zroot/var
    chmod 1777 /mnt/tmp
}

partitionner_manuellement() {
    bsdinstall partedit
    echo "Relancez le script une fois le partitionnement terminé."
    exit 0
}

configurer_reseau() {
    echo "=== Configuration du réseau ==="
    echo "1) Automatique (Ethernet ou Wi-Fi scan)"
    echo "2) Manuelle (Wi-Fi avec SSID/PSK)"
    read -p "Choix [1-2]: " net_choice

    if [ "$net_choice" = "1" ]; then
        interfaces=$(ifconfig -l)
        for iface in $interfaces; do
            if echo "$iface" | grep -qE '^em|^re|^igb|^ue'; then
                echo "DHCP sur $iface..."
                dhclient "$iface" && echo "Connecté via $iface" && return
            fi
        done
        for iface in $interfaces; do
            if echo "$iface" | grep -qE '^wlan'; then
                echo "Interface Wi-Fi détectée : $iface"
                ifconfig "$iface" up
                ifconfig "$iface" scan
                echo "Utilisez le mode manuel pour Wi-Fi."
                return
            fi
        done
        echo "Pas d'interface réseau valide trouvée."
    else
        read -p "Interface Wi-Fi (ex: wlan0): " wlan
        ifconfig "$wlan" up
        ifconfig "$wlan" scan
        read -p "SSID Wi-Fi : " ssid
        read -s -p "Mot de passe : " psk
        echo
        cat > /etc/wpa_supplicant.conf <<EOF
network={
    ssid=\"$ssid\"
    psk=\"$psk\"
}
EOF
        wpa_supplicant -B -i "$wlan" -c /etc/wpa_supplicant.conf
        dhclient "$wlan" && echo "Connecté via $wlan" || echo "Échec de connexion"
    fi
}

installer_base() {
    bsdinstall distfetch
    bsdinstall installconfig
    bsdinstall mount
    bsdinstall config
    bsdinstall rootpass
    bsdinstall adduser
    bsdinstall network
}

choisir_environnement_bureau() {
    echo "=== Choix de l'environnement graphique ==="
    echo "1) XFCE"
    echo "2) KDE Plasma"
    echo "3) GNOME"
    echo "4) MATE"
    echo "5) Aucun"
    read -p "Choix [1-5]: " desktop_choice
}

installer_environnement_bureau() {
    pkg bootstrap -y
    pkg update

    case "$desktop_choice" in
        1)
            pkg install -y xorg xfce slim
            echo 'exec startxfce4' > /mnt/home/*/.xinitrc
            echo 'slim_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        2)
            pkg install -y xorg plasma5 sddm kde5
            echo 'exec startplasma-x11' > /mnt/home/*/.xinitrc
            echo 'sddm_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        3)
            pkg install -y xorg gnome gdm
            echo 'exec gnome-session' > /mnt/home/*/.xinitrc
            echo 'gdm_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        4)
            pkg install -y xorg mate slim
            echo 'exec mate-session' > /mnt/home/*/.xinitrc
            echo 'slim_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        *)
            echo "Pas d'environnement graphique installé."
            ;;
    esac
    echo 'dbus_enable="YES"' >> /mnt/etc/rc.conf
}

finalisation() {
    echo "Installation terminée. Vous pouvez maintenant redémarrer."
}

### === Exécution principale === ###

choisir_langue
detecter_disques
choisir_mode_boot
choisir_partitionnement

if [ "$part_mode" = "1" ]; then
    partitionner_disque_auto
else
    partitionner_manuellement
fi

configurer_reseau
installer_base
choisir_environnement_bureau
installer_environnement_bureau
finalisation
