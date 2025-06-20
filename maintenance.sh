#!/bin/sh
# Script de maintenance simple ZFS pour FreeBSD

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
