# Script d'Installation Automatisée FreeBSD

Ce script shell guide l'installation de FreeBSD avec les options suivantes :

- Choix de la langue (Français / Anglais)  
- Détection des disques disponibles  
- Choix du mode de démarrage (UEFI ou BIOS Legacy)  
- Partitionnement automatique (ZFS) ou manuel  
- Configuration réseau avec choix automatique DHCP Ethernet ou Wi-Fi manuel  
- Installation de l’environnement de bureau (XFCE, KDE Plasma, GNOME, MATE, ou aucun)  
- Post-installation : auto-login root optionnel, installation de sudo, affichage automatique de `zfs list` à la connexion root  
- Option de génération d'une ISO d'installation automatisée (requiert outils spécifiques)

---

## Prérequis

- Exécuter ce script en tant que `root` depuis un environnement FreeBSD LiveCD / installer  
- Connexion internet fonctionnelle pour l'installation des paquets  
- Disque cible identifié (ex : ada0, da0)  
- Pour la génération ISO : `mkisofs` ou `genisoimage` installés sur la machine hôte

---

## Utilisation

1. Télécharger le script et le rendre exécutable :

```sh
chmod +x install_freebsd.sh
