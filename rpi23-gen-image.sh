#!/bin/sh
########################################################################
# rpi23-gen-image.sh					       2015-2017
#
# Advanced Debian "stretch" and "buster" bootstrap script for Raspberry Pi
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# Copyright (C) 2015 Jan Wagner <mail@jwagner.eu>
#
# Big thanks for patches and enhancements by 20+ github contributors!
########################################################################

# Are we running as root?
if [ "$(id -u)" -ne "0" ] ; then
  echo "error: this script must be executed with root privileges!"
  exit 1
fi

# Check if ./functions.sh script exists
if [ ! -r "./functions.sh" ] ; then
  echo "error: './functions.sh' required script not found!"
  exit 1
fi

# Load utility functions
. ./functions.sh

# Load parameters from configuration template file
if [ -n "$CONFIG_TEMPLATE" ] ; then
  use_template
fi

# Introduce settings
set -e
echo -n -e "\n#\n# RPi 0/1/2/3 Bootstrap Settings\n#\n"
set -x

# Raspberry Pi model configuration
RPI_MODEL=${RPI_MODEL:=2}

# Debian release
RELEASE=${RELEASE:=buster}
if [ $RELEASE = "bullseye" ] ; then
 RELEASE=testing
fi

# Kernel Branch
KERNEL_BRANCH=${KERNEL_BRANCH:=""}

# URLs
KERNEL_URL=${KERNEL_URL:=https://github.com/raspberrypi/linux}
FIRMWARE_URL=${FIRMWARE_URL:=https://github.com/raspberrypi/firmware/raw/master/boot}
WLAN_FIRMWARE_URL=${WLAN_FIRMWARE_URL:=https://github.com/RPi-Distro/firmware-nonfree/raw/master/brcm}
COLLABORA_URL=${COLLABORA_URL:=https://repositories.collabora.co.uk/debian}
FBTURBO_URL=${FBTURBO_URL:=https://github.com/ssvb/xf86-video-fbturbo.git}
UBOOT_URL=${UBOOT_URL:=https://git.denx.de/u-boot.git}
VIDEOCORE_URL=${VIDEOCORE_URL:=https://github.com/raspberrypi/userland}
BLUETOOTH_URL=${BLUETOOTH_URL:=https://github.com/RPi-Distro/pi-bluetooth.git}
NEXMON_URL=${NEXMON_URL:=https://github.com/seemoo-lab/nexmon.git}
SYSTEMDSWAP_URL=${SYSTEMDSWAP_URL:=https://github.com/Nefelim4ag/systemd-swap.git}

# Kernel deb packages for 32bit kernel
RPI_32_KERNEL_URL=${RPI_32_KERNEL_URL:=https://github.com/hypriot/rpi-kernel/releases/download/v4.14.34/raspberrypi-kernel_20180422-141901_armhf.deb}
RPI_32_KERNELHEADER_URL=${RPI_32_KERNELHEADER_URL:=https://github.com/hypriot/rpi-kernel/releases/download/v4.14.34/raspberrypi-kernel-headers_20180422-141901_armhf.deb}
# Kernel has KVM and zswap enabled - use if KERNEL_* parameters and precompiled kernel are used 
RPI3_64_BIS_KERNEL_URL=${RPI3_64_BIS_KERNEL_URL:=https://github.com/sakaki-/bcmrpi3-kernel-bis/releases/download/4.14.80.20181113/bcmrpi3-kernel-bis-4.14.80.20181113.tar.xz}
RPI3_64_BIS_KERNEL_URL=${RPI3_64_BIS_KERNEL_URL:=https://github.com/sakaki-/bcmrpi3-kernel-bis/releases/download/4.19.80.20191022/bcmrpi3-kernel-bis-4.19.80.20191022.tar.xz}
# Default precompiled 64bit kernel
RPI3_64_DEF_KERNEL_URL=${RPI3_64_DEF_KERNEL_URL:=https://github.com/sakaki-/bcmrpi3-kernel/releases/download/4.14.80.20181113/bcmrpi3-kernel-4.14.80.20181113.tar.xz}
RPI3_64_DEF_KERNEL_URL=${RPI3_64_DEF_KERNEL_URL:=https://github.com/sakaki-/bcmrpi3-kernel/releases/download/4.19.80.20191022/bcmrpi3-kernel-4.19.80.20191022.tar.xz}
# Sakaki BIS Kernel RPI4 - https://github.com/sakaki-/bcm2711-kernel-bis
RPI4_64_BIS_KERNEL_URL=${RPI4_64_BIS_KERNEL_URL:=https://github.com/sakaki-/bcm2711-kernel-bis/releases/download/4.19.59.20190724/bcm2711-kernel-bis-4.19.59.20190724.tar.xz}
# Default precompiled 64bit kernel - https://github.com/sakaki-/bcm2711-kernel
RPI4_64_DEF_KERNEL_URL=${RPI4_64_DEF_KERNEL_URL:=https://github.com/sakaki-/bcm2711-kernel-bis/releases/download/4.19.59.20190724/bcm2711-kernel-bis-4.19.59.20190724.tar.xz}
# Generic 
RPI3_64_KERNEL_URL=${RPI3_64_KERNEL_URL:=$RPI3_64_DEF_KERNEL_URL}
RPI4_64_KERNEL_URL=${RPI4_64_KERNEL_URL:=$RPI4_64_DEF_KERNEL_URL}
# Kali kernel src - used if ENABLE_NEXMON=true (they patch the wlan kernel modul)
KALI_KERNEL_URL=${KALI_KERNEL_URL:=https://github.com/Re4son/re4son-raspberrypi-linux.git}

# Build directories
WORKDIR=$(pwd)
BASEDIR=${BASEDIR:=${WORKDIR}/images/${RELEASE}}
BUILDDIR="${BASEDIR}/build"

# Chroot directories
R="${BUILDDIR}/chroot"
ETC_DIR="${R}/etc"
LIB_DIR="${R}/lib"
BOOT_DIR="${R}/boot/firmware"
KERNEL_DIR="${R}/usr/src/linux"
WLAN_FIRMWARE_DIR="${LIB_DIR}/firmware/brcm"
BLUETOOTH_FIRMWARE_DIR="${ETC_DIR}/firmware/bt"

# Firmware directory: Blank if download from github
RPI_FIRMWARE_DIR=${RPI_FIRMWARE_DIR:=""}

# General settings
SET_ARCH=${SET_ARCH:=32}
HOSTNAME=${HOSTNAME:=rpi${RPI_MODEL}-${RELEASE}}
PASSWORD=${PASSWORD:=raspberry}
USER_PASSWORD=${USER_PASSWORD:=raspberry}
DEFLOCAL=${DEFLOCAL:="en_US.UTF-8"}
TIMEZONE=${TIMEZONE:="Europe/Berlin"}
EXPANDROOT=${EXPANDROOT:=true}
ENABLE_DPHYSSWAP=${ENABLE_DPHYSSWAP:=true}

# Keyboard settings
XKB_MODEL=${XKB_MODEL:=""}
XKB_LAYOUT=${XKB_LAYOUT:=""}
XKB_VARIANT=${XKB_VARIANT:=""}
XKB_OPTIONS=${XKB_OPTIONS:=""}

# Network settings (DHCP)
ENABLE_DHCP=${ENABLE_DHCP:=true}

# Network settings (static)
NET_ADDRESS=${NET_ADDRESS:=""}
NET_GATEWAY=${NET_GATEWAY:=""}
NET_DNS_1=${NET_DNS_1:=""}
NET_DNS_2=${NET_DNS_2:=""}
NET_DNS_DOMAINS=${NET_DNS_DOMAINS:=""}
NET_NTP_1=${NET_NTP_1:=""}
NET_NTP_2=${NET_NTP_2:=""}

# APT settings
APT_PROXY=${APT_PROXY:=""}
APT_SERVER=${APT_SERVER:="ftp.debian.org"}
KEEP_APT_PROXY=${KEEP_APT_PROXY:=false}

# Feature settings
ENABLE_PRINTK=${ENABLE_PRINTK:=false}
ENABLE_BLUETOOTH=${ENABLE_BLUETOOTH:=false}
ENABLE_MINIUART_OVERLAY=${ENABLE_MINIUART_OVERLAY:=false}
ENABLE_CONSOLE=${ENABLE_CONSOLE:=true}
ENABLE_I2C=${ENABLE_I2C:=false}
ENABLE_SPI=${ENABLE_SPI:=false}
ENABLE_IPV6=${ENABLE_IPV6:=true}
ENABLE_SSHD=${ENABLE_SSHD:=true}
ENABLE_NONFREE=${ENABLE_NONFREE:=false}
ENABLE_WIRELESS=${ENABLE_WIRELESS:=false}
ENABLE_SOUND=${ENABLE_SOUND:=true}
ENABLE_DBUS=${ENABLE_DBUS:=true}
ENABLE_HWRANDOM=${ENABLE_HWRANDOM:=true}
ENABLE_MINGPU=${ENABLE_MINGPU:=false}
ENABLE_XORG=${ENABLE_XORG:=false}
ENABLE_WM=${ENABLE_WM:=""}
ENABLE_RSYSLOG=${ENABLE_RSYSLOG:=true}
ENABLE_USER=${ENABLE_USER:=true}
USER_NAME=${USER_NAME:="pi"}
ENABLE_ROOT=${ENABLE_ROOT:=false}
ENABLE_QEMU=${ENABLE_QEMU:=false}
ENABLE_SYSVINIT=${ENABLE_SYSVINIT:=false}

# SSH settings
SSH_ENABLE_ROOT=${SSH_ENABLE_ROOT:=false}
SSH_DISABLE_PASSWORD_AUTH=${SSH_DISABLE_PASSWORD_AUTH:=false}
SSH_LIMIT_USERS=${SSH_LIMIT_USERS:=false}
SSH_ROOT_PUB_KEY=${SSH_ROOT_PUB_KEY:=""}
SSH_USER_PUB_KEY=${SSH_USER_PUB_KEY:=""}

# Advanced settings
ENABLE_SYSTEMDSWAP=${ENABLE_SYSTEMDSWAP:=false}
ENABLE_MINBASE=${ENABLE_MINBASE:=false}
ENABLE_REDUCE=${ENABLE_REDUCE:=false}
ENABLE_UBOOT=${ENABLE_UBOOT:=false}
UBOOTSRC_DIR=${UBOOTSRC_DIR:=""}
ENABLE_USBBOOT=${ENABLE_USBBOOT=false}
ENABLE_FBTURBO=${ENABLE_FBTURBO:=false}
ENABLE_VIDEOCORE=${ENABLE_VIDEOCORE:=false}
ENABLE_NEXMON=${ENABLE_NEXMON:=false}
VIDEOCORESRC_DIR=${VIDEOCORESRC_DIR:=""}
FBTURBOSRC_DIR=${FBTURBOSRC_DIR:=""}
NEXMONSRC_DIR=${NEXMONSRC_DIR:=""}
ENABLE_HARDNET=${ENABLE_HARDNET:=false}
ENABLE_IPTABLES=${ENABLE_IPTABLES:=false}
ENABLE_SPLITFS=${ENABLE_SPLITFS:=false}
ENABLE_INITRAMFS=${ENABLE_INITRAMFS:=false}
ENABLE_IFNAMES=${ENABLE_IFNAMES:=true}
ENABLE_SPLASH=${ENABLE_SPLASH:=true}
ENABLE_LOGO=${ENABLE_LOGO:=true}
ENABLE_SILENT_BOOT=${ENABLE_SILENT_BOOT=false}
DISABLE_UNDERVOLT_WARNINGS=${DISABLE_UNDERVOLT_WARNINGS:=}

# Kernel compilation settings
BUILD_KERNEL=${BUILD_KERNEL:=true}
KERNEL_REDUCE=${KERNEL_REDUCE:=false}
KERNEL_THREADS=${KERNEL_THREADS:=1}
KERNEL_HEADERS=${KERNEL_HEADERS:=true}
KERNEL_MENUCONFIG=${KERNEL_MENUCONFIG:=false}
KERNEL_REMOVESRC=${KERNEL_REMOVESRC:=true}
KERNEL_OLDDEFCONFIG=${KERNEL_OLDDEFCONFIG:=false}
KERNEL_CCACHE=${KERNEL_CCACHE:=false}
KERNEL_ZSWAP=${KERNEL_ZSWAP:=false}
KERNEL_VIRT=${KERNEL_VIRT:=false}
KERNEL_BPF=${KERNEL_BPF:=false}
KERNEL_DEFAULT_GOV=${KERNEL_DEFAULT_GOV:=ondemand}
KERNEL_SECURITY=${KERNEL_SECURITY:=false}
KERNEL_NF=${KERNEL_NF:=false}
KERNEL_DHKEY=${KERNEL_DHKEY:=true}
KERNEL_BTRFS=${KERNEL_BTRFS:=false}
KERNEL_NSPAN=${KERNEL_NSPAN:=false}
KERNEL_POEHAT=${KERNEL_POEHAT:=false}

# Kernel compilation from source directory settings
KERNELSRC_DIR=${KERNELSRC_DIR:=""}
KERNELSRC_CLEAN=${KERNELSRC_CLEAN:=false}
KERNELSRC_CONFIG=${KERNELSRC_CONFIG:=true}
KERNELSRC_PREBUILT=${KERNELSRC_PREBUILT:=false}

# Reduce disk usage settings
REDUCE_APT=${REDUCE_APT:=true}
REDUCE_DOC=${REDUCE_DOC:=true}
REDUCE_MAN=${REDUCE_MAN:=true}
REDUCE_VIM=${REDUCE_VIM:=false}
REDUCE_BASH=${REDUCE_BASH:=false}
REDUCE_HWDB=${REDUCE_HWDB:=true}
REDUCE_SSHD=${REDUCE_SSHD:=true}
REDUCE_LOCALE=${REDUCE_LOCALE:=true}

# Encrypted filesystem settings
ENABLE_CRYPTFS=${ENABLE_CRYPTFS:=false}
CRYPTFS_PASSWORD=${CRYPTFS_PASSWORD:=""}
CRYPTFS_MAPPING=${CRYPTFS_MAPPING:="secure"}
CRYPTFS_CIPHER=${CRYPTFS_CIPHER:="aes-xts-plain64:sha512"}
CRYPTFS_CIPHER=${CRYPTFS_CIPHER:="aes-xts-plain64"}
CRYPTFS_HASH=${CRYPTFS_HASH:="sha512"}
CRYPTFS_XTSKEYSIZE=${CRYPTFS_XTSKEYSIZE:=512}
#Dropbear-initramfs supports unlocking encrypted filesystem via SSH on bootup
CRYPTFS_DROPBEAR=${CRYPTFS_DROPBEAR:=false}
#Provide your own Dropbear Public RSA-OpenSSH Key otherwise it will be generated
CRYPTFS_DROPBEAR_PUBKEY=${CRYPTFS_DROPBEAR_PUBKEY:=""}

# Chroot scripts directory
CHROOT_SCRIPTS=${CHROOT_SCRIPTS:=""}

# Packages required in the chroot build environment
APT_INCLUDES=${APT_INCLUDES:=""}
APT_INCLUDES="${APT_INCLUDES},apt-transport-https,apt-utils,ca-certificates,debian-archive-keyring,dialog,sudo,systemd,sysvinit-utils,locales,keyboard-configuration,console-setup,libnss-systemd"
APT_INCLUDES="${APT_INCLUDES},flex,bison,libssl-dev,apt-transport-https,apt-utils,ca-certificates,debian-archive-keyring,dialog,sudo,systemd,sysvinit-utils,locales,keyboard-configuration,console-setup,libnss-systemd"

# Packages to exclude from chroot build environment
APT_EXCLUDES=${APT_EXCLUDES:=""}

# Packages required for bootstrapping
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc dbus sudo"
REQUIRED_PACKAGES="debootstrap debian-archive-keyring qemu-user-static binfmt-support dosfstools rsync bmap-tools whois git bc psmisc dbus bison flex libssl-dev sudo"
MISSING_PACKAGES=""

# Packages installed for c/c++ build environment in chroot (keep empty)
COMPILER_PACKAGES=""

# Check if apt-cacher-ng has port 3142 open and set APT_PROXY
APT_CACHER_RUNNING=$(lsof -i :3142 | cut -d ' ' -f3 | uniq | sed '/^\s*$/d')
if [ "${APT_CACHER_RUNNING}" = "apt-cacher-ng" ] ; then
  APT_PROXY=http://127.0.0.1:3142/
fi

# Setup architecture specific settings
if [ -n "$SET_ARCH" ] ; then
  # 64-bit configuration
  if [ "$SET_ARCH" = 64 ] ; then
    # General 64-bit depended settings
    QEMU_BINARY=${QEMU_BINARY:=/usr/bin/qemu-aarch64-static}
    KERNEL_ARCH=${KERNEL_ARCH:=arm64}
    KERNEL_BIN_IMAGE=${KERNEL_BIN_IMAGE:="Image"}

    # Raspberry Pi model specific settings
    if [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] || [ "$RPI_MODEL" = 4 ] ; then
      if [ "$RPI_MODEL" != 4 ] ; then
        KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcmrpi3_defconfig}
      else
        KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcm2711_defconfig}
      fi
      
      REQUIRED_PACKAGES="${REQUIRED_PACKAGES} crossbuild-essential-arm64"
      RELEASE_ARCH=${RELEASE_ARCH:=arm64}
      KERNEL_IMAGE=${KERNEL_IMAGE:=kernel8.img}
      CROSS_COMPILE=${CROSS_COMPILE:=aarch64-linux-gnu-}
    else
      echo "error: Only Raspberry PI 3, 3B+ and 4 support 64-bit"
      exit 1
    fi
  fi

  # 32-bit configuration
  if [ "$SET_ARCH" = 32 ] ; then
    # General 32-bit dependend settings
    QEMU_BINARY=${QEMU_BINARY:=/usr/bin/qemu-arm-static}
    KERNEL_ARCH=${KERNEL_ARCH:=arm}
    KERNEL_BIN_IMAGE=${KERNEL_BIN_IMAGE:="zImage"}

    # Raspberry Pi model specific settings
    if [ "$RPI_MODEL" = 0 ] || [ "$RPI_MODEL" = 1 ] || [ "$RPI_MODEL" = 1P ] ; then
      REQUIRED_PACKAGES="${REQUIRED_PACKAGES} crossbuild-essential-armel"
      KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcmrpi_defconfig}
      RELEASE_ARCH=${RELEASE_ARCH:=armel}
      KERNEL_IMAGE=${KERNEL_IMAGE:=kernel.img}
      CROSS_COMPILE=${CROSS_COMPILE:=arm-linux-gnueabi-}
    fi

    # Raspberry Pi model specific settings
    if [ "$RPI_MODEL" = 2 ] || [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] || [ "$RPI_MODEL" = 4 ] ; then
      if [ "$RPI_MODEL" != 4 ] ; then
        KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcm2709_defconfig}
		KERNEL_IMAGE=${KERNEL_IMAGE:=kernel7.img}
      else
        KERNEL_DEFCONFIG=${KERNEL_DEFCONFIG:=bcm2711_defconfig}
		KERNEL_IMAGE=${KERNEL_IMAGE:=kernel7l.img}
      fi
      
      REQUIRED_PACKAGES="${REQUIRED_PACKAGES} crossbuild-essential-armhf"
      RELEASE_ARCH=${RELEASE_ARCH:=armhf}
      KERNEL_IMAGE=${KERNEL_IMAGE:=kernel7.img}
      
      CROSS_COMPILE=${CROSS_COMPILE:=arm-linux-gnueabihf-}
    fi
  fi
# SET_ARCH not set
else
  echo "error: Please set '32' or '64' as value for SET_ARCH"
  exit 1
fi
# Device specific configuration and U-Boot configuration
case "$RPI_MODEL" in
  0)
    DTB_FILE=${DTB_FILE:=bcm2708-rpi-0-w.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_defconfig}
    ;;
  1)
    DTB_FILE=${DTB_FILE:=bcm2708-rpi-b.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_defconfig}
    ;;
  1P)
    DTB_FILE=${DTB_FILE:=bcm2708-rpi-b-plus.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_defconfig}
    ;;
  2)
    DTB_FILE=${DTB_FILE:=bcm2709-rpi-2-b.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_2_defconfig}
    ;;
  3)
    DTB_FILE=${DTB_FILE:=bcm2710-rpi-3-b.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_3_defconfig}
    ;;
  3P)
    DTB_FILE=${DTB_FILE:=bcm2710-rpi-3-b.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_3_defconfig}
    ;;
  4)
    DTB_FILE=${DTB_FILE:=bcm2711-rpi-4-b.dtb}
    UBOOT_CONFIG=${UBOOT_CONFIG:=rpi_4_defconfig}
    ;;
  *)
    echo "error: Raspberry Pi model $RPI_MODEL is not supported!"
    exit 1
    ;;
esac

# Raspberry PI 0,3,3P with Bluetooth and Wifi onboard
if [ "$RPI_MODEL" = 0 ] || [ "$RPI_MODEL" = 3 ] || [ "$RPI_MODEL" = 3P ] || [ "$RPI_MODEL" = 4 ] ; then
  # Include bluetooth packages on supported boards
  if [ "$ENABLE_BLUETOOTH" = true ] ; then
    APT_INCLUDES="${APT_INCLUDES},bluetooth,bluez"
  fi
  if [ "$ENABLE_WIRELESS" = true ] ; then
    APT_INCLUDES="${APT_INCLUDES},wireless-tools,crda,wireless-regdb"
  fi
else # Raspberry PI 1,1P,2 without Wifi and bluetooth onboard
  # Check if the internal wireless interface is not supported by the RPi model
  if [ "$ENABLE_WIRELESS" = true ] || [ "$ENABLE_BLUETOOTH" = true ]; then
    echo "error: The selected Raspberry Pi model has no integrated interface for wireless or bluetooth"
    exit 1
  fi
fi

if [ "$BUILD_KERNEL" = false ] && [ "$ENABLE_NEXMON" = true ]; then
  echo "error: You have to compile kernel sources, if you want to enable nexmon"
  exit 1
fi

# Prepare date string for default image file name
DATE="$(date +%Y-%m-%d)"
if [ -z "$KERNEL_BRANCH" ] ; then
  IMAGE_NAME=${IMAGE_NAME:=${BASEDIR}/${DATE}-${KERNEL_ARCH}-CURRENT-rpi${RPI_MODEL}-${RELEASE}-${RELEASE_ARCH}}
else
  IMAGE_NAME=${IMAGE_NAME:=${BASEDIR}/${DATE}-${KERNEL_ARCH}-${KERNEL_BRANCH}-rpi${RPI_MODEL}-${RELEASE}-${RELEASE_ARCH}}
fi

# Check if DISABLE_UNDERVOLT_WARNINGS parameter value is supported
if [ -n "$DISABLE_UNDERVOLT_WARNINGS" ] ; then
  if [ "$DISABLE_UNDERVOLT_WARNINGS" != 1 ] && [ "$DISABLE_UNDERVOLT_WARNINGS" != 2 ] ; then
    echo "error: DISABLE_UNDERVOLT_WARNINGS=${DISABLE_UNDERVOLT_WARNINGS} is not supported"
    exit 1
  fi
fi

# Add cmake to compile videocore sources
if [ "$ENABLE_VIDEOCORE" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} cmake"
fi

# Add deps for nexmon
if [ "$ENABLE_NEXMON" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} libgmp3-dev gawk qpdf bison flex make autoconf automake build-essential libtool"
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} libgmp3-dev gawk qpdf make autoconf automake build-essential libtool"
fi

# Add libncurses5 to enable kernel menuconfig
if [ "$KERNEL_MENUCONFIG" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} libncurses-dev"
fi

# Add ccache compiler cache for (faster) kernel cross (re)compilation
if [ "$KERNEL_CCACHE" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} ccache"
fi

# Add cryptsetup package to enable filesystem encryption
if [ "$ENABLE_CRYPTFS" = true ]  && [ "$BUILD_KERNEL" = true ] ; then
  REQUIRED_PACKAGES="${REQUIRED_PACKAGES} cryptsetup"
  APT_INCLUDES="${APT_INCLUDES},cryptsetup,busybox,console-setup"
  APT_INCLUDES="${APT_INCLUDES},cryptsetup,busybox,console-setup,cryptsetup-initramfs"

  # If cryptfs,dropbear and initramfs are enabled include dropbear-initramfs package
  if [ "$CRYPTFS_DROPBEAR" = true ] && [ "$ENABLE_INITRAMFS" = true ]; then
    APT_INCLUDES="${APT_INCLUDES},dropbear-initramfs"
  fi
  
  if [ -z "$CRYPTFS_PASSWORD" ] ; then
    echo "error: no password defined (CRYPTFS_PASSWORD)!"
    exit 1
  fi
  ENABLE_INITRAMFS=true
fi

# Add initramfs generation tools
if [ "$ENABLE_INITRAMFS" = true ] && [ "$BUILD_KERNEL" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},initramfs-tools"
fi

# Add device-tree-compiler required for building the U-Boot bootloader
if [ "$ENABLE_UBOOT" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},device-tree-compiler,bison,flex,bc"
fi

if [ "$ENABLE_USBBOOT" = true ] ; then 
  if [ "$RPI_MODEL" = 0 ] || [ "$RPI_MODEL" = 1P ] || [ "$RPI_MODEL" = 1 ] || [ "$RPI_MODEL" = 2 ]; then
    echo "error: Booting from USB alone is only supported by Raspberry Pi 3 and 3P"
    exit 1
  fi
fi

# Check if root SSH (v2) public key file exists
if [ -n "$SSH_ROOT_PUB_KEY" ] ; then
  if [ ! -f "$SSH_ROOT_PUB_KEY" ] ; then
    echo "error: '$SSH_ROOT_PUB_KEY' specified SSH public key file not found (SSH_ROOT_PUB_KEY)!"
    exit 1
  fi
fi

# Check if $USER_NAME SSH (v2) public key file exists
if [ -n "$SSH_USER_PUB_KEY" ] ; then
  if [ ! -f "$SSH_USER_PUB_KEY" ] ; then
    echo "error: '$SSH_USER_PUB_KEY' specified SSH public key file not found (SSH_USER_PUB_KEY)!"
    exit 1
  fi
fi

if [ "$ENABLE_NEXMON" = true ] && [ -n "$KERNEL_BRANCH" ] ; then
  echo "error: Please unset KERNEL_BRANCH if using ENABLE_NEXMON"
  exit 1
fi

# Check if all required packages are installed on the build system
for package in $REQUIRED_PACKAGES ; do
  if [ "$(dpkg-query -W -f='${Status}' "$package")" != "install ok installed" ] ; then
    MISSING_PACKAGES="${MISSING_PACKAGES} $package"
  fi
done

# If there are missing packages ask confirmation for install, or exit
if [ -n "$MISSING_PACKAGES" ] ; then
  echo "the following packages needed by this script are not installed:"
  echo "$MISSING_PACKAGES"

  printf "\ndo you want to install the missing packages right now? [y/n] "
  read -r confirm
  [ "$confirm" != "y" ] && exit 1

  # Make sure all missing required packages are installed
  apt-get -qq -y install `echo "${MISSING_PACKAGES}" | sed "s/ //"`
  apt-get update && apt-get -qq -y install `echo "${MISSING_PACKAGES}" | sed "s/ //"`
fi

# Check if ./bootstrap.d directory exists
if [ ! -d "./bootstrap.d/" ] ; then
  echo "error: './bootstrap.d' required directory not found!"
  exit 1
fi

# Check if ./files directory exists
if [ ! -d "./files/" ] ; then
  echo "error: './files' required directory not found!"
  exit 1
fi

# Check if specified KERNELSRC_DIR directory exists
if [ -n "$KERNELSRC_DIR" ] && [ ! -d "$KERNELSRC_DIR" ] ; then
  echo "error: '${KERNELSRC_DIR}' specified directory not found (KERNELSRC_DIR)!"
  exit 1
fi

# Check if specified UBOOTSRC_DIR directory exists
if [ -n "$UBOOTSRC_DIR" ] && [ ! -d "$UBOOTSRC_DIR" ] ; then
  echo "error: '${UBOOTSRC_DIR}' specified directory not found (UBOOTSRC_DIR)!"
  exit 1
fi

# Check if specified VIDEOCORESRC_DIR directory exists
if [ -n "$VIDEOCORESRC_DIR" ] && [ ! -d "$VIDEOCORESRC_DIR" ] ; then
  echo "error: '${VIDEOCORESRC_DIR}' specified directory not found (VIDEOCORESRC_DIR)!"
  exit 1
fi

# Check if specified FBTURBOSRC_DIR directory exists
if [ -n "$FBTURBOSRC_DIR" ] && [ ! -d "$FBTURBOSRC_DIR" ] ; then
  echo "error: '${FBTURBOSRC_DIR}' specified directory not found (FBTURBOSRC_DIR)!"
  exit 1
fi

# Check if specified NEXMONSRC_DIR directory exists
if [ -n "$NEXMONSRC_DIR" ] && [ ! -d "$NEXMONSRC_DIR" ] ; then
  echo "error: '${NEXMONSRC_DIR}' specified directory not found (NEXMONSRC_DIR)!"
  exit 1
fi

# Check if specified CHROOT_SCRIPTS directory exists
if [ -n "$CHROOT_SCRIPTS" ] && [ ! -d "$CHROOT_SCRIPTS" ] ; then
   echo "error: ${CHROOT_SCRIPTS} specified directory not found (CHROOT_SCRIPTS)!"
   exit 1
fi

# Check if specified device mapping already exists (will be used by cryptsetup)
if [ -r "/dev/mapping/${CRYPTFS_MAPPING}" ] ; then
  echo "error: mapping /dev/mapping/${CRYPTFS_MAPPING} already exists, not proceeding"
  exit 1
fi

# Don't clobber an old build
if [ -e "$BUILDDIR" ] ; then
  echo "error: directory ${BUILDDIR} already exists, not proceeding"
  exit 1
fi

# Setup chroot directory
mkdir -p "${R}"

# Check if build directory has enough of free disk space >512MB
if [ "$(df --output=avail "${BUILDDIR}" | sed "1d")" -le "524288" ] ; then
  echo "error: ${BUILDDIR} not enough space left to generate the output image!"
  exit 1
fi

set -x

# Call "cleanup" function on various signals and errors
trap cleanup 0 1 2 3 6

# Add required packages for the minbase installation
if [ "$ENABLE_MINBASE" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},vim-tiny,netbase,net-tools,ifupdown"
fi

# Add parted package, required to get partprobe utility
if [ "$EXPANDROOT" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},parted"
fi

# Add dphys-swapfile package, required to enable swap
if [ "$ENABLE_DPHYSSWAP" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},dphys-swapfile"
fi

# Add dbus package, recommended if using systemd
if [ "$ENABLE_DBUS" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},dbus"
fi

# Add iptables IPv4/IPv6 package
if [ "$ENABLE_IPTABLES" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},iptables,iptables-persistent"
fi
# Add apparmor for KERNEL_SECURITY
if [ "$KERNEL_SECURITY" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},apparmor,apparmor-utils,apparmor-profiles,apparmor-profiles-extra,libapparmor-perl"
fi

# Add openssh server package
if [ "$ENABLE_SSHD" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},openssh-server"
fi

# Add alsa-utils package
if [ "$ENABLE_SOUND" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},alsa-utils"
fi

# Add rng-tools package
if [ "$ENABLE_HWRANDOM" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},rng-tools"
fi

# Add fbturbo video driver
if [ "$ENABLE_FBTURBO" = true ] ; then
  # Enable xorg package dependencies
  ENABLE_XORG=true
fi

# Add user defined window manager package
if [ -n "$ENABLE_WM" ] ; then
  APT_INCLUDES="${APT_INCLUDES},${ENABLE_WM}"

  # Enable xorg package dependencies
  ENABLE_XORG=true
fi

# Add xorg package
if [ "$ENABLE_XORG" = true ] ; then
  APT_INCLUDES="${APT_INCLUDES},xorg,dbus-x11"
fi

# Replace selected packages with smaller clones
if [ "$ENABLE_REDUCE" = true ] ; then
  # Add levee package instead of vim-tiny
  if [ "$REDUCE_VIM" = true ] ; then
    APT_INCLUDES="$(echo ${APT_INCLUDES} | sed "s/vim-tiny/levee/")"
  fi

  # Add dropbear package instead of openssh-server
  if [ "$REDUCE_SSHD" = true ] ; then
    APT_INCLUDES="$(echo "${APT_INCLUDES}" | sed "s/openssh-server/dropbear/")"
  fi
fi

# Configure systemd-sysv exclude to make halt/reboot/shutdown scripts available
if [ "$ENABLE_SYSVINIT" = false ] ; then
  APT_EXCLUDES="--exclude=${APT_EXCLUDES},init,systemd-sysv"
fi

# Configure kernel sources if no KERNELSRC_DIR
if [ "$BUILD_KERNEL" = true ] && [ -z "$KERNELSRC_DIR" ] ; then
  KERNELSRC_CONFIG=true
fi

# Configure reduced kernel
if [ "$KERNEL_REDUCE" = true ] ; then
  KERNELSRC_CONFIG=false
fi

# Configure qemu compatible kernel
if [ "$ENABLE_QEMU" = true ] ; then
  DTB_FILE=vexpress-v2p-ca15_a7.dtb
  UBOOT_CONFIG=vexpress_ca15_tc2_defconfig
  KERNEL_DEFCONFIG="vexpress_defconfig"
  if [ "$KERNEL_MENUCONFIG" = false ] ; then
    KERNEL_OLDDEFCONFIG=true
  fi
fi

# Execute bootstrap scripts
for SCRIPT in bootstrap.d/*.sh; do
  head -n 3 "$SCRIPT"
  . "$SCRIPT"
done

## Execute custom bootstrap scripts
if [ -d "custom.d" ] ; then
  for SCRIPT in custom.d/*.sh; do
    . "$SCRIPT"
  done
fi

# Execute custom scripts inside the chroot
if [ -n "$CHROOT_SCRIPTS" ] && [ -d "$CHROOT_SCRIPTS" ] ; then
  cp -r "${CHROOT_SCRIPTS}" "${R}/chroot_scripts"
  chroot_exec /bin/bash -x <<'EOF'
for SCRIPT in /chroot_scripts/* ; do
  if [ -f $SCRIPT -a -x $SCRIPT ] ; then
    $SCRIPT
  fi
done
EOF
  rm -rf "${R}/chroot_scripts"
fi

# Remove c/c++ build environment from the chroot
chroot_remove_cc

# Generate required machine-id
MACHINE_ID=$(dbus-uuidgen)
echo -n "${MACHINE_ID}" > "${R}/var/lib/dbus/machine-id"
echo -n "${MACHINE_ID}" > "${ETC_DIR}/machine-id"

# APT Cleanup
chroot_exec apt-get -y clean
chroot_exec apt-get -y autoclean
chroot_exec apt-get -y autoremove

# Unmount mounted filesystems
umount -l "${R}/proc"
umount -l "${R}/sys"

# Clean up directories
rm -rf "${R}/run/*"
rm -rf "${R}/tmp/*"

# Clean up APT proxy settings
if [ "$KEEP_APT_PROXY" = false ] ; then
  rm -f "${ETC_DIR}/apt/apt.conf.d/10proxy"
fi

# Clean up files
rm -f "${ETC_DIR}/ssh/ssh_host_*"
rm -f "${ETC_DIR}/dropbear/dropbear_*"
rm -f "${ETC_DIR}/apt/sources.list.save"
rm -f "${ETC_DIR}/resolvconf/resolv.conf.d/original"
rm -f "${ETC_DIR}/*-"
rm -f "${ETC_DIR}/resolv.conf"
rm -f "${R}/root/.bash_history"
rm -f "${R}/var/lib/urandom/random-seed"
rm -f "${R}/initrd.img"
rm -f "${R}/vmlinuz"
rm -f "${R}${QEMU_BINARY}"

if [ "$ENABLE_QEMU" = true ] ; then
  # Setup QEMU directory
  mkdir "${BASEDIR}/qemu"

  # Copy kernel image to QEMU directory
  install_readonly "${BOOT_DIR}/${KERNEL_IMAGE}" "${BASEDIR}/qemu/${KERNEL_IMAGE}"

  # Copy kernel config to QEMU directory
  install_readonly "${R}/boot/config-${KERNEL_VERSION}" "${BASEDIR}/qemu/config-${KERNEL_VERSION}"

  # Copy kernel dtbs to QEMU directory
  for dtb in "${BOOT_DIR}/"*.dtb ; do
    if [ -f "${dtb}" ] ; then
      install_readonly "${dtb}" "${BASEDIR}/qemu/"
    fi
  done

  # Copy kernel overlays to QEMU directory
  if [ -d "${BOOT_DIR}/overlays" ] ; then
    # Setup overlays dtbs directory
    mkdir "${BASEDIR}/qemu/overlays"

    for dtb in "${BOOT_DIR}/overlays/"*.dtbo ; do
      if [ -f "${dtb}" ] ; then
        install_readonly "${dtb}" "${BASEDIR}/qemu/overlays/"
      fi
    done
  fi

  # Copy u-boot files to QEMU directory
  if [ "$ENABLE_UBOOT" = true ] ; then
    if [ -f "${BOOT_DIR}/u-boot.bin" ] ; then
      install_readonly "${BOOT_DIR}/u-boot.bin" "${BASEDIR}/qemu/u-boot.bin"
    fi
    if [ -f "${BOOT_DIR}/uboot.mkimage" ] ; then
      install_readonly "${BOOT_DIR}/uboot.mkimage" "${BASEDIR}/qemu/uboot.mkimage"
    fi
    if [ -f "${BOOT_DIR}/boot.scr" ] ; then
      install_readonly "${BOOT_DIR}/boot.scr" "${BASEDIR}/qemu/boot.scr"
    fi
  fi

  # Copy initramfs to QEMU directory
  if [ -f "${BOOT_DIR}/initramfs-${KERNEL_VERSION}" ] ; then
    install_readonly "${BOOT_DIR}/initramfs-${KERNEL_VERSION}" "${BASEDIR}/qemu/initramfs-${KERNEL_VERSION}"
  fi
fi

# Calculate size of the chroot directory in KB
CHROOT_SIZE=$(expr "$(du -s "${R}" | awk '{ print $1 }')")

# Calculate the amount of needed 512 Byte sectors
TABLE_SECTORS=$(expr 1 \* 1024 \* 1024 \/ 512)
FRMW_SECTORS=$(expr 64 \* 1024 \* 1024 \/ 512)
ROOT_OFFSET=$(expr "${TABLE_SECTORS}" + "${FRMW_SECTORS}")

# The root partition is EXT4
# This means more space than the actual used space of the chroot is used.
# As overhead for journaling and reserved blocks 35% are added.
ROOT_SECTORS=$(expr "$(expr "${CHROOT_SIZE}" + "${CHROOT_SIZE}" \/ 100 \* 35)" \* 1024 \/ 512)

# Calculate required image size in 512 Byte sectors
IMAGE_SECTORS=$(expr "${TABLE_SECTORS}" + "${FRMW_SECTORS}" + "${ROOT_SECTORS}")

# Prepare image file
if [ "$ENABLE_SPLITFS" = true ] ; then
  dd if=/dev/zero of="$IMAGE_NAME-frmw.img" bs=512 count="${TABLE_SECTORS}"
  dd if=/dev/zero of="$IMAGE_NAME-frmw.img" bs=512 count=0 seek="${FRMW_SECTORS}"
  dd if=/dev/zero of="$IMAGE_NAME-root.img" bs=512 count="${TABLE_SECTORS}"
  dd if=/dev/zero of="$IMAGE_NAME-root.img" bs=512 count=0 seek="${ROOT_SECTORS}"

  # Write firmware/boot partition tables
  sfdisk -q -L -uS -f "$IMAGE_NAME-frmw.img" 2> /dev/null <<EOM
${TABLE_SECTORS},${FRMW_SECTORS},c,*
EOM

  # Write root partition table
  sfdisk -q -L -uS -f "$IMAGE_NAME-root.img" 2> /dev/null <<EOM
${TABLE_SECTORS},${ROOT_SECTORS},83
EOM

  # Setup temporary loop devices
  FRMW_LOOP="$(losetup -o 1M --sizelimit 64M -f --show "$IMAGE_NAME"-frmw.img)"
  ROOT_LOOP="$(losetup -o 1M -f --show "$IMAGE_NAME"-root.img)"
else # ENABLE_SPLITFS=false
  dd if=/dev/zero of="$IMAGE_NAME.img" bs=512 count="${TABLE_SECTORS}"
  dd if=/dev/zero of="$IMAGE_NAME.img" bs=512 count=0 seek="${IMAGE_SECTORS}"

  # Write partition table
  sfdisk -q -L -uS -f "$IMAGE_NAME.img" 2> /dev/null <<EOM
${TABLE_SECTORS},${FRMW_SECTORS},c,*
${ROOT_OFFSET},${ROOT_SECTORS},83
EOM

  # Setup temporary loop devices
  FRMW_LOOP="$(losetup -o 1M --sizelimit 64M -f --show "$IMAGE_NAME".img)"
  ROOT_LOOP="$(losetup -o 65M -f --show "$IMAGE_NAME".img)"
fi

if [ "$ENABLE_CRYPTFS" = true ] ; then
  # Create dummy ext4 fs
  mkfs.ext4 "$ROOT_LOOP"

  # Setup password keyfile
  touch .password
  chmod 600 .password
  echo -n ${CRYPTFS_PASSWORD} > .password

  # Initialize encrypted partition
  echo "YES" | cryptsetup luksFormat "${ROOT_LOOP}" -c "${CRYPTFS_CIPHER}" -s "${CRYPTFS_XTSKEYSIZE}" .password
  cryptsetup --verbose --debug -q luksFormat "${ROOT_LOOP}" -c "${CRYPTFS_CIPHER}" -h "${CRYPTFS_HASH}" -s "${CRYPTFS_XTSKEYSIZE}" .password

  # Open encrypted partition and setup mapping
  cryptsetup luksOpen "${ROOT_LOOP}" -d .password "${CRYPTFS_MAPPING}"

  # Secure delete password keyfile
  shred -zu .password

  # Update temporary loop device
  ROOT_LOOP="/dev/mapper/${CRYPTFS_MAPPING}"

  # Wipe encrypted partition (encryption cipher is used for randomness)
  dd if=/dev/zero of="${ROOT_LOOP}" bs=512 count="$(blockdev --getsz "${ROOT_LOOP}")"
fi

# Build filesystems
mkfs.vfat "$FRMW_LOOP"
mkfs.ext4 "$ROOT_LOOP"

# Mount the temporary loop devices
mkdir -p "$BUILDDIR/mount"
mount "$ROOT_LOOP" "$BUILDDIR/mount"

mkdir -p "$BUILDDIR/mount/boot/firmware"
mount "$FRMW_LOOP" "$BUILDDIR/mount/boot/firmware"

# Copy all files from the chroot to the loop device mount point directory
rsync -a "${R}/" "$BUILDDIR/mount/"

# Unmount all temporary loop devices and mount points
cleanup

# Create block map file(s) of image(s)
if [ "$ENABLE_SPLITFS" = true ] ; then
  # Create block map files for "bmaptool"
  bmaptool create -o "$IMAGE_NAME-frmw.bmap" "$IMAGE_NAME-frmw.img"
  bmaptool create -o "$IMAGE_NAME-root.bmap" "$IMAGE_NAME-root.img"

  # Image was successfully created
  echo "$IMAGE_NAME-frmw.img ($(expr \( "${TABLE_SECTORS}" + "${FRMW_SECTORS}" \) \* 512 \/ 1024 \/ 1024)M)" ": successfully created"
  echo "$IMAGE_NAME-root.img ($(expr \( "${TABLE_SECTORS}" + "${ROOT_SECTORS}" \) \* 512 \/ 1024 \/ 1024)M)" ": successfully created"
else
  # Create block map file for "bmaptool"
  bmaptool create -o "$IMAGE_NAME.bmap" "$IMAGE_NAME.img"

  # Image was successfully created
  echo "$IMAGE_NAME.img ($(expr \( "${TABLE_SECTORS}" + "${FRMW_SECTORS}" + "${ROOT_SECTORS}" \) \* 512 \/ 1024 \/ 1024)M)" ": successfully created"

  # Create qemu qcow2 image
  if [ "$ENABLE_QEMU" = true ] ; then
    QEMU_IMAGE=${QEMU_IMAGE:=${BASEDIR}/qemu/${DATE}-${KERNEL_ARCH}-CURRENT-rpi${RPI_MODEL}-${RELEASE}-${RELEASE_ARCH}}
    QEMU_SIZE=16G

    qemu-img convert -f raw -O qcow2 "$IMAGE_NAME".img "$QEMU_IMAGE".qcow2
    qemu-img resize "$QEMU_IMAGE".qcow2 $QEMU_SIZE

    echo "$QEMU_IMAGE.qcow2 ($QEMU_SIZE)" ": successfully created"
  fi
fi
