function get_mounted_disks {
    # Detects all base physical disks that have at least one mounted partition
    lsblk -nd -o NAME | while read -r disk; do
        if lsblk -n -o MOUNTPOINT "/dev/${disk}" 2>/dev/null | grep -q "^/"; then
            echo "/dev/${disk}"
        fi
    done
}