#!/bin/sh
# Script de maintenance simple pour les pools ZFS sous FreeBSD
#
# Ce script effectue plusieurs tâches de maintenance courantes pour
# assurer la santé et la propreté de vos pools ZFS :
#
# 1) Affiche le statut actuel de tous les pools ZFS avec `zpool status`
# 2) Liste tous les datasets (filesystems, volumes) existants avec `zfs list`
# 3) Lance un scrub (vérification d'intégrité) sur tous les pools détectés
#    Cela permet de détecter et corriger les erreurs sur les disques
# 4) Propose de supprimer les snapshots plus vieux que 30 jours afin de
#    libérer de l’espace disque (optionnel, à utiliser avec précaution)
#
# Usage : exécuter ce script en tant que root sur votre système FreeBSD.
# Attention : la suppression des snapshots est irréversible !
#
# Vous pouvez modifier la durée de conservation des snapshots en adaptant
# la variable dans la partie suppression (ici 30 jours).
#
# Ce script est utile pour une maintenance régulière et la prévention
# des problèmes liés aux pools ZFS.
#

echo "=== Statut des pools ZFS ==="
zpool status

echo
echo "=== Liste des datasets ZFS ==="
zfs list

echo
echo "=== Scrub (vérification) des pools ZFS ==="
for pool in $(zpool list -H -o name); do
    echo "Lancement du scrub pour $pool"
    zpool scrub "$pool"
done

echo
echo "=== Nettoyage des snapshots > 30 jours ==="
read -p "Voulez-vous supprimer les snapshots plus vieux que 30 jours ? (y/n) " del_snap
if [ "$del_snap" = "y" ]; then
    for snap in $(zfs list -t snapshot -o name -H); do
        creation_date=$(zfs get -H -o value creation "$snap")
        creation_epoch=$(date -j -f "%a %b %d %H:%M %Y" "$creation_date" +%s)
        now_epoch=$(date +%s)
        diff_days=$(( (now_epoch - creation_epoch) / 86400 ))
        if [ "$diff_days" -gt 30 ]; then
            echo "Suppression du snapshot $snap (créé il y a $diff_days jours)"
            zfs destroy "$snap"
        fi
    done
else
    echo "Aucune suppression effectuée."
fi

echo "Maintenance ZFS terminée."
