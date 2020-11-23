#!/usr/bin/env bash
set -euo pipefail

# Script needs to be run as root!
if [ $EUID -ne 0 ]
    then
        echo "you need to run me as root"
    exit 1
fi

mapperName="cryptdrive"

availableDrives=`sudo fdisk -l | grep "Disk" | grep -v "Disklabel\|identifier" | cut -d " " -f 2 | cut -d ":" -f1`

list_drives () {

    # gather the attached disks on the system and print them out

    local availableDrives=`sudo fdisk -l | grep "Disk" | grep -v "Disklabel\|identifier" | cut -d " " -f 2 | cut -d ":" -f1`
    local counter=1

    for drive in ${availableDrives}
    do
        echo ${counter}. ${drive}
        counter=$((counter+1))
    done

}

check_if_mounted () {

    # two args: <file system location> and <drive>

    if mount | grep ${1} > /dev/null
    then
        echo "Device '${2}' is Mounted at location '${1}'!"
    else
        echo "Device ${2} is NOT mounted"
    fi

}

mount_drive () {

    # mount the drive

    list_drives

    echo "Enter the drive you wish to work on ex. 1 <Enter> "
    read drive
    selectedDrive=`list_drives | grep ${drive} | cut -d " " -f2`

    local mountLocation=""

    until [ -d "${mountLocation}" ]
    do
        echo "Enter the mount location: "
        read mountLocation
    done

    sudo cryptsetup luksOpen ${selectedDrive} ${mapperName}
    sudo mount /dev/mapper/${mapperName} ${mountLocation}

    check_if_mounted ${mountLocation} ${selectedDrive}

}

check_for_drive () {

    # check to see if cryptsetup has a drive mapped under the predefined
    # mapperName variable (cryptdrive) and echo True or Falsed based on that
    # result

    sudo cryptsetup -v status ${mapperName} &> /dev/null

    if [ $? != 0 ]
    then
        echo "False"
    else
        echo "True"
    fi

}

find_mount_location () {

    # find the mount location of a drive that is currently under the cryptsetup
    # mapperName (cryptdrive) variable

    local mountLocation=`sudo cryptsetup -v status ${mapperName} | grep "device:" | cut -d : -f2 | xargs`

    echo ${mountLocation}

}


unmount_drive () {

    # un-mount a drive
    local answer=""

    if [ `check_for_drive` == "True" ]
    then
        mountedDrive=`find_mount_location`
        echo "Found device ${mountedDrive} is an encrypted drive that is currently mounted, do you want to un mount that one or enter one manually?"
        echo "Y: Unmount ${mapperName}"
        echo "M: Enter device manually."
        read answer

        if [ `echo ${answer} | cut -c1 | tr [:upper:] [:lower:]` == "m" ]
        then
            echo "Enter the mount location: "
            read mountLocation
        elif  [ `echo ${answer} | cut -c1 | tr [:upper:] [:lower:]` == "y" ]
        then
            mountLocation=`sudo mount | grep /dev/mapper/${mapperName} | cut -d " " -f3`
        else
            echo "Invalid selection please try again!"
            exit 1
        fi
     else
        echo "Unable to detect an encrypted drive that is mounted!"
        exit 1

    fi

    sudo umount ${mountLocation}
    sudo cryptsetup luksClose ${mapperName}

}

encrypt_drive () {

    # encrypt drive

    list_drives

    echo "Enter the drive you wish to encrypt ex. 1 <enter> "
    read answer
    local drive=`list_drives | grep ${answer} | cut -d " " -f2`

    sudo cryptsetup -y -v luksFormat ${drive}

    echo "Now Decrypting the drive to finish the process and create file system."
    sudo cryptsetup luksOpen ${drive} ${mapperName}

    echo "Do you want to write all zeros to the drive for true security?"
    echo "NOTE! This will take a long time especially if the drive is large!"
    read confirmation

    # cleans up the answer from the user and checks to see if the first letter is a 'y'
    if [ `echo ${confirmation} | cut -c1 | tr [:upper:] [:lower:]` == "y" ]
    then
        sudo dd if=/dev/zero of=/dev/mapper/${mapperName} status=progress bs=4M
    fi

    echo "Creating EXT4 file system"
    sudo mkfs.ext4 /dev/mapper/${mapperName}

    sudo cryptsetup luksClose ${mapperName}

}

if [ $# -eq 0 ]
then
    echo "Please supply one argument (--mount, --encrypt or --unmount)"
fi
   
if [ "$1" == "--mount" ]
then
    mount_drive
elif [ "$1" == "--unmount" ]
then
    unmount_drive
elif [ "$1" == "--encrypt" ]
then
    lsblk
    echo
    encrypt_drive
else
    echo "$1 is an invalid argument!"
fi
