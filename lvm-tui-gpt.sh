#!/bin/bash

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "This script requires 'dialog'. Please install it first (e.g., 'sudo apt-get install dialog' on Debian/Ubuntu)"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Temporary file for dialog output
TEMP=/tmp/lvm_config_$$.tmp
trap 'rm -f $TEMP' EXIT

# Function to display error message
error_msg() {
    dialog --msgbox "Error: $1" 10 40
}

# Function to get available disks
get_disks() {
    lsblk -d -n -o NAME | grep -v "loop" | while read disk; do
        echo "/dev/$disk"
    done | tr '\n' ' '
}

# Main menu
while true; do
    dialog --menu "LVM Configuration Tool" 15 50 7 \
        1 "Create Physical Volume" \
        2 "Create Volume Group" \
        3 "Create Logical Volume" \
        4 "List LVM Information" \
        5 "Extend Logical Volume" \
        6 "Remove Logical Volume" \
        7 "Exit" 2> $TEMP
    
    choice=$(cat $TEMP)
    [ -z "$choice" ] && break

    case $choice in
        1) # Create Physical Volume
            DISKS=$(get_disks)
            dialog --menu "Select disk for Physical Volume" 15 50 5 \
                $DISKS 2> $TEMP
            disk=$(cat $TEMP)
            if [ -n "$disk" ]; then
                if pvcreate "$disk" 2>/dev/null; then
                    dialog --msgbox "Physical Volume created successfully on $disk" 10 40
                else
                    error_msg "Failed to create Physical Volume on $disk"
                fi
            fi
            ;;

        2) # Create Volume Group
            dialog --inputbox "Enter Volume Group name" 8 40 2> $TEMP
            vgname=$(cat $TEMP)
            if [ -n "$vgname" ]; then
                DISKS=$(get_disks)
                dialog --menu "Select Physical Volume for VG" 15 50 5 \
                    $DISKS 2> $TEMP
                pv=$(cat $TEMP)
                if [ -n "$pv" ]; then
                    if vgcreate "$vgname" "$pv" 2>/dev/null; then
                        dialog --msgbox "Volume Group $vgname created successfully" 10 40
                    else
                        error_msg "Failed to create Volume Group"
                    fi
                fi
            fi
            ;;

        3) # Create Logical Volume
            dialog --inputbox "Enter Volume Group name" 8 40 2> $TEMP
            vgname=$(cat $TEMP)
            dialog --inputbox "Enter Logical Volume name" 8 40 2> $TEMP
            lvname=$(cat $TEMP)
            dialog --inputbox "Enter size (e.g., 10G)" 8 40 2> $TEMP
            size=$(cat $TEMP)
            if [ -n "$vgname" ] && [ -n "$lvname" ] && [ -n "$size" ]; then
                if lvcreate -L "$size" -n "$lvname" "$vgname" 2>/dev/null; then
                    dialog --msgbox "Logical Volume $lvname created successfully" 10 40
                else
                    error_msg "Failed to create Logical Volume"
                fi
            fi
            ;;

        4) # List LVM Information
            {
                echo "Physical Volumes:"
                pvdisplay
                echo -e "\nVolume Groups:"
                vgdisplay
                echo -e "\nLogical Volumes:"
                lvdisplay
            } > /tmp/lvm_info.txt
            dialog --textbox /tmp/lvm_info.txt 20 70
            rm -f /tmp/lvm_info.txt
            ;;

        5) # Extend Logical Volume
            dialog --inputbox "Enter Logical Volume path (e.g., /dev/vgname/lvname)" 8 40 2> $TEMP
            lvpath=$(cat $TEMP)
            dialog --inputbox "Enter additional size (e.g., +5G)" 8 40 2> $TEMP
            size=$(cat $TEMP)
            if [ -n "$lvpath" ] && [ -n "$size" ]; then
                if lvextend -L "$size" "$lvpath" 2>/dev/null; then
                    dialog --msgbox "Logical Volume extended successfully" 10 40
                else
                    error_msg "Failed to extend Logical Volume"
                fi
            fi
            ;;

        6) # Remove Logical Volume
            dialog --inputbox "Enter Logical Volume path (e.g., /dev/vgname/lvname)" 8 40 2> $TEMP
            lvpath=$(cat $TEMP)
            if [ -n "$lvpath" ]; then
                dialog --yesno "Are you sure you want to remove $lvpath?" 7 60
                if [ $? -eq 0 ]; then
                    if lvremove -f "$lvpath" 2>/dev/null; then
                        dialog --msgbox "Logical Volume removed successfully" 10 40
                    else
                        error_msg "Failed to remove Logical Volume"
                    fi
                fi
            fi
            ;;

        7) # Exit
            break
            ;;
    esac
done

clear
echo "LVM Configuration Tool closed"
exit 0
