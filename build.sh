#!/usr/bin/env bash

# Library files
source 'lib.sh'

# Variables
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="${PWD}/output"
REMOVE_WORKDIR=0

RELEASE="bionic"
MIRROR="http://ch.archive.ubuntu.com/ubuntu/"
KERNEL="linux-generic-hwe-18.04"

usage() {
  echo "Usage: $0 [-h] [-f]" 1>&2
  exit 1
}

create_build_dir() {
  if [ -d "${WORKDIR}" ]; then
    if ((REMOVE_WORKDIR)); then
      rm -rf $WORKDIR
    else
      error "Non-empty workdir!"
    fi
  fi

  mkdir -p "${WORKDIR}" || error "Can't create workdir!"
  mkdir -p "${WORKDIR}/image/casper" || error "Can't create dir for casper!"
}

run_debootstrap() {
  debootstrap \
    --arch=amd64 \
    --variant=minbase \
    "${RELEASE}" \
    "${WORKDIR}/chroot" \
    "${MIRROR}"
}

mount_devices() {
  mount --bind /dev "${WORKDIR}/chroot/dev" || error "Mounting /dev inside chroot!"
  mount --bind /run "${WORKDIR}/chroot/run" || error "Mounting /run inside chroot!"
  mount none -t proc "${WORKDIR}/chroot/proc" || error "Mounting /proc inside chroot!"
  mount none -t sysfs "${WORKDIR}/chroot/sys" || error "Mounting /sys inside chroot!"
  mount none -t devpts "${WORKDIR}/chroot/dev/pts" || error "Mounting /dev/pts inside chroot!"
}

umount_devices() {
  umount "${WORKDIR}/chroot/dev/pts" || true
  umount "${WORKDIR}/chroot/sys" || true
  umount "${WORKDIR}/chroot/proc" || true
  umount "${WORKDIR}/chroot/run" || true
  umount "${WORKDIR}/chroot/dev" || true
}

create_squashfs() {
  mksquashfs "${WORKDIR}/chroot" "${WORKDIR}/image/casper/filesystem.squashfs"
}

configure_grub() {

  cat <<EOF > "${WORKDIR}/mnt/boot/grub/grub.cfg"
search --set=root --file /liveimage

insmod all_video

set default="0"
set timeout=0

menuentry "Run Image" {
   linux /vmlinuz boot=casper splash ---
   initrd /initrd
}

EOF
}

build_image() {
  BLOCK_SIZE="512"

  local chroot_size=$(ls -sk "${WORKDIR}/image/casper/filesystem.squashfs" | awk '{print $1}')
  local disk_size_blocks=$(echo "((${chroot_size} * 1024) + (200 * 1024 * 1024)) / ${BLOCK_SIZE}" | bc)

  # create empty disk image
  dd if=/dev/zero of="${WORKDIR}/disk.img" bs="${BLOCK_SIZE}" count="${disk_size_blocks}" || error "Couldn't create diskimage"

  sgdisk -og "${WORKDIR}/disk.img"

  local endsector=$(sgdisk -E "${WORKDIR}/disk.img")
  sgdisk -n 1:2048:4095 -c 1:"BIOS Boot Partition" -t 1:ef02 "${WORKDIR}/disk.img" > /dev/null 2>&1 || error "Couldn't create BIOS BOOT partition"
  sgdisk -n 2:4096:206848 -c 2:"EFI System Partition" -t 2:ef00 "${WORKDIR}/disk.img" > /dev/null 2>&1 || error "Couldn't create EFI partition"
  sgdisk -n 3:206849:${endsector} -c 3:"System Partition" -t 3:0700 "${WORKDIR}/disk.img" > /dev/null 2>&1 || error "Coldn't create system partition"

  sgdisk -p "${WORKDIR}/disk.img"

  local dev=$(losetup --show -f -P "${WORKDIR}/disk.img")

  mkfs.vfat "${dev}p2"
  mkfs.vfat "${dev}p3"

  mkdir "${WORKDIR}/mnt"
  mount "${dev}p3" "${WORKDIR}/mnt"

  touch "${WORKDIR}/image/liveimage"
  cp -a ${WORKDIR}/image/* "${WORKDIR}/mnt"

  mkdir -p "${WORKDIR}/mnt/boot/grub" "${WORKDIR}/chroot/boot/grub" "${WORKDIR}/chroot/boot/efi"

  configure_grub

  mount_devices
  mount -o bind "${WORKDIR}/mnt/boot/grub" "${WORKDIR}/chroot/boot/grub"
  mount "${dev}p2" "${WORKDIR}/chroot/boot/efi"

  chroot "${WORKDIR}/chroot" grub-install \
    --target=i386-pc \
    --boot-directory="/boot" \
    ${dev}

  chroot "${WORKDIR}/chroot" grub-install \
    --target=x86_64-efi \
    --uefi-secure-boot \
    --no-nvram \
    --removable \
    --efi-directory="/boot/efi" \
    --boot-directory="/boot" \
    ${dev}

  sleep 5
  sync

  umount "${WORKDIR}/chroot/boot/efi"
  umount "${WORKDIR}/chroot/boot/grub"
  umount_devices

  umount "${WORKDIR}/mnt"
  rmdir "${WORKDIR}/mnt"

  losetup -d ${dev}
}

run_buildscript() {
  local script=$1

  echo "Running: '${script}'"
  chroot "${WORKDIR}/chroot" /bin/bash -x <<EOF
MIRROR="${MIRROR}"
RELEASE="${RELEASE}"
KERNEL="${KERNEL}"

export HISTSIZE=0
export HOME=/root
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

$(cat ${script})
EOF

  # check if script was successful...
  if (($?)); then error "Failure running build-script '$script'"; fi
}

while getopts ":hfd:" OPT; do
  case "${OPT}" in
    h)
      usage
      ;;
    d)
      WORKDIR="${OPTARG}"
      ;;
    f)
      REMOVE_WORKDIR=1
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

check_root
check_command "chroot"
check_command "debootstrap"
check_command "mksquashfs"

create_build_dir

run_debootstrap

trap 'umount_devices' SIGTERM SIGINT SIGQUIT SIGTSTP
mount_devices

for file in ${SCRIPT_DIR}/build-scripts/*.sh; do
  run_buildscript $file
done

umount_devices
trap - SIGTERM SIGINT SIGQUIT SIGTSTP

cp ${WORKDIR}/chroot/boot/vmlinuz-*-generic "${WORKDIR}/image/vmlinuz" || error "Couldn't copy vmlinuz"
cp ${WORKDIR}/chroot/boot/initrd.img-*-generic "${WORKDIR}/image/initrd" || error "Couldn't copy initrd"

create_squashfs

build_image
