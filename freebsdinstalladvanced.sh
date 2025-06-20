#!/bin/sh

###############################################################################
# TUTORIEL DE CONNEXION RÉSEAU (si non détecté automatiquement)
# Ethernet : dhclient <interface>
# Wi-Fi : ifconfig wlan0 up
#         ifconfig wlan0 scan
#         vi /etc/wpa_supplicant.conf
#         network={
#             ssid="MonSSID"
#             psk="MonMotDePasse"
#         }
#         wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
#         dhclient wlan0
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
    echo "=== Choix configuration réseau ==="
    echo "1) Automatique DHCP Ethernet (sinon Wi-Fi manuel)"
    echo "2) Wi-Fi manuel"
    read -p "Choix [1-2]: " net_choice

    if [ "$net_choice" = "1" ]; then
        interfaces=$(ifconfig -l)
        for iface in $interfaces; do
            if echo "$iface" | grep -qE '^(em|re|igb|ue)'; then
                echo "DHCP sur interface Ethernet : $iface"
                if dhclient "$iface"; then
                    echo "Connecté via $iface"
                    return
                else
                    echo "Échec DHCP sur $iface"
                fi
            fi
        done
        echo "Pas d'interface Ethernet détectée ou DHCP échoué."
        echo "Passage en mode Wi-Fi manuel..."
    fi

    read -p "Interface Wi-Fi (ex: wlan0): " wlan
    ifconfig "$wlan" up
    ifconfig "$wlan" scan
    read -p "SSID Wi-Fi : " ssid
    read -s -p "Mot de passe : " psk
    echo
    cat > /etc/wpa_supplicant.conf <<EOF
network={
    ssid="$ssid"
    psk="$psk"
}
EOF
    wpa_supplicant -B -i "$wlan" -c /etc/wpa_supplicant.conf
    if dhclient "$wlan"; then
        echo "Connecté via $wlan"
    else
        echo "Échec de connexion Wi-Fi"
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
            echo 'exec startxfce4' > /mnt/root/.xinitrc
            echo 'slim_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        2)
            pkg install -y xorg plasma5 sddm kde5
            echo 'exec startplasma-x11' > /mnt/root/.xinitrc
            echo 'sddm_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        3)
            pkg install -y xorg gnome gdm
            echo 'exec gnome-session' > /mnt/root/.xinitrc
            echo 'gdm_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        4)
            pkg install -y xorg mate slim
            echo 'exec mate-session' > /mnt/root/.xinitrc
            echo 'slim_enable="YES"' >> /mnt/etc/rc.conf
            ;;
        *)
            echo "Pas d'environnement graphique installé."
            ;;
    esac
    echo 'dbus_enable="YES"' >> /mnt/etc/rc.conf
}

configurer_post_install() {
    echo "=== Configuration post-installation ==="
    read -p "Activer auto-login pour root ? (y/n) : " alogin
    if [ "$alogin" = "y" ]; then
        echo 'getty_mode="autologin"' >> /mnt/etc/ttys
    fi

    read -p "Installer sudo pour root et utilisateurs ? (y/n) : " sudo_install
    if [ "$sudo_install" = "y" ]; then
        chroot /mnt pkg install -y sudo
        echo 'permit : wheel' >> /mnt/usr/local/etc/sudoers
        echo '%wheel ALL=(ALL) ALL' >> /mnt/usr/local/etc/sudoers
        echo "wheel ALL=(ALL) ALL" >> /mnt/usr/local/etc/sudoers
    fi

    # Script post-login zfs list
    echo '#!/bin/sh' > /mnt/root/.login_zfs_list.sh
    echo 'echo "Vos pools ZFS :" ' >> /mnt/root/.login_zfs_list.sh
    echo 'zfs list' >> /mnt/root/.login_zfs_list.sh
    echo 'read -p "Appuyez sur Entrée pour continuer..."' >> /mnt/root/.login_zfs_list.sh
    chmod +x /mnt/root/.login_zfs_list.sh
    echo 'echo "sh ~/.login_zfs_list.sh" >> /mnt/root/.profile' >> /mnt/root/.login_zfs_list.sh

    echo "Post-installation configurée."
}

generer_iso() {
    echo "=== Génération ISO automatisée (optionnel) ==="
    echo "Cette fonction nécessite 'mkisofs' ou 'genisoimage' et une source FreeBSD LiveCD."
    read -p "Chemin vers source FreeBSD LiveCD : " src
    read -p "Chemin de sortie ISO personnalisée : " outiso

    if [ ! -d "$src" ]; then
        echo "Source introuvable."
        return
    fi

    echo "Copie des fichiers et ajout du script d'installation automatisée..."
    # Ceci est un exemple, à adapter selon besoin réel

    cp -r "$src" /tmp/freebsd-iso
    echo "Ajout du script dans /tmp/freebsd-iso/root/auto_install.sh"
    cp "$0" /tmp/freebsd-iso/root/auto_install.sh
    chmod +x /tmp/freebsd-iso/root/auto_install.sh

    echo "Création de l'ISO..."
    mkisofs -o "$outiso" -b boot/cdboot -no-emul-boot -J -R /tmp/freebsd-iso
    echo "ISO créée : $outiso"
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
configurer_post_install

echo "Installation terminée. Vous pouvez maintenant redémarrer."

echo
read -p "Voulez-vous générer une ISO d'installation automatisée ? (y/n): " geniso
if [ "$geniso" = "y" ]; then
    generer_iso
fi
