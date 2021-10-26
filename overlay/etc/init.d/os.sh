#!/bin/sh

# TODO: POSIX sh doesn't support export of funtion.
# The function is defined again.
quit_job()
{
    echo -e "$*"
    /bin/sh
}

# Retrive the partition info from the config file.
#  "rdisk": {
#    "partition": "3",
#    "hash_tree": "hash_tree",
#    "root_hash": "d76aabb2255c8b0d1fb6f454cf363f8845e14cc900156c36d63c4c36794dca4a"
#  },
#  "wdisk": {
#    "partition": "4"
#  }
# For readonly partition, there should be partition number, the hash tree file name, and the root hash string.
# For writable partition, there should be partition number.
config_file=$config_destination/image_config.json
os_r_partition=`jq -r .rdisk.partition $config_file`
os_w_partition=`jq -r .wdisk.partition $config_file`

# Create the partition devices and mount points.
mknod /dev/${os_drive_letter}${os_r_partition} b 8 ${os_r_partition}
mknod /dev/${os_drive_letter}${os_w_partition} b 8 ${os_w_partition}

readonly_destination=/mnt/${os_drive_letter}${os_r_partition}
writable_destination=/mnt/${os_drive_letter}${os_w_partition}
overlay_destination=/mnt/$os_drive_letter
mkdir $readonly_destination $writable_destination $overlay_destination -p

# Verification of the ro partition
config_hash=`sha256sum $config_file | cut -d" " -f1`
recorded_hash=`/attestation/get_family_id_image_id.sh`
if [ "$config_hash" != "$recorded_hash" ]; then
    quit_job "Config file does not match the record."
else
    echo "Config file matches the record."
fi


os_r_hash_tree=$config_destination/$(jq -r .rdisk.hash_tree $config_file)
os_r_root_hash=`jq -r .rdisk.root_hash $config_file`

# Set the options to empty string first.
os_r_option=""
os_w_option=""

# "veritysetup create ..." will not prompt any error even the verification fails.
# Add extra verification step "veritysetup verify ..." to get more info.
# In some case the verification will fail randomly.
# So only add the verification info only if the mount fails.
creation_result=`veritysetup create dm$os_r_partition /dev/${os_drive_letter}$os_r_partition $os_r_hash_tree $os_r_root_hash 2>&1`
mount_result=`mount -o ro,noload /dev/mapper/dm$os_r_partition $readonly_destination`
if [ $? -ne 0 ]; then
    verification_result=`veritysetup verify /dev/${os_drive_letter}$os_r_partition $os_r_hash_tree $os_r_root_hash`
    quit_job "${verification_result}\n${creation_result}\n${mount_result}\nDm-verity device mapper mounting failed."
else
    echo "Dm-verity device mapper mounting succeeded."
    echo "Readonly disk $os_r_partition is mounted on $readonly_destination."
    os_r_option="-o lowerdir=$readonly_destination"
fi

passwd=`cat /dev/urandom | base64 | head -c 32`
echo $passwd | cryptsetup luksFormat /dev/${os_drive_letter}$os_w_partition
echo $passwd | cryptsetup open /dev/${os_drive_letter}$os_w_partition dm$os_w_partition
echo y | mkfs.ext2 /dev/mapper/dm$os_w_partition
mount /dev/mapper/dm$os_w_partition $writable_destination

if [ $? -ne 0 ]; then
    quit_job "mount writable disk /dev/${os_drive_letter}$os_w_partition on $writable_destination failed."
else
    echo "mount writable disk /dev/${os_drive_letter}$os_w_partition on $writable_destination succeded."
    mkdir $writable_destination/upperdir $writable_destination/workdir -p
    os_w_option="-o upperdir=$writable_destination/upperdir,workdir=$writable_destination/workdir"

fi

mount -t overlay overlay $os_r_option $os_w_option $overlay_destination
if [ $? -ne 0 ]; then
    quit_job "mount overlay failed."
else
    echo "mount overlay succeded."
fi
# If the rootfs is not empty, we can switch to the rootfs
# chroot /mnt/${os_drive_letter} /bin/bash
# chroot to /mnt/${os_drive_letter}. In the new rootfs, start an infinite job bash.
if [ "`ls -A $overlay_destination`" != "" ]; then
    chroot /mnt/${os_drive_letter} /bin/bash
else
# Unexpected route, add an inifinite job /bin/sh on the initrd.
    quit_job "Unexpected execution route."
fi
