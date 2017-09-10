# This file contains utility functions used by rpi23-gen-image.sh

cleanup (){
  set +x
  set +e

  # Identify and kill all processes still using files
  echo "killing processes using mount point ..."
  fuser -k "${R}"
  sleep 3
  fuser -9 -k -v "${R}"

  # Clean up temporary .password file
  if [ -r ".password" ] ; then
    shred -zu .password
  fi

  # Clean up all temporary mount points
  echo "removing temporary mount points ..."
  umount -l "${R}/proc" 2> /dev/null
  umount -l "${R}/sys" 2> /dev/null
  umount -l "${R}/dev/pts" 2> /dev/null
  umount "$BUILDDIR/mount/boot/firmware" 2> /dev/null
  umount "$BUILDDIR/mount" 2> /dev/null
  cryptsetup close "${CRYPTFS_MAPPING}" 2> /dev/null
  losetup -d "$ROOT_LOOP" 2> /dev/null
  losetup -d "$FRMW_LOOP" 2> /dev/null
  trap - 0 1 2 3 6
}

chroot_exec() {
  # Exec command in chroot
  LANG=C LC_ALL=C DEBIAN_FRONTEND=noninteractive chroot ${R} $*
}

as_nobody() {
  # Exec command as user nobody
  sudo -E -u nobody LANG=C LC_ALL=C $*
}

install_readonly() {
  # Install file with user read-only permissions
  install -o root -g root -m 644 $*
}

install_exec() {
  # Install file with root exec permissions
  install -o root -g root -m 744 $*
}

use_template () {
  # Test if configuration template file exists
  if [ ! -r "./templates/${CONFIG_TEMPLATE}" ] ; then
    echo "error: configuration template ${CONFIG_TEMPLATE} not found"
    exit 1
  fi

  # Load template configuration parameters
  . "./templates/${CONFIG_TEMPLATE}"
}

chroot_install_cc() {
  # Install c/c++ build environment inside the chroot
  if [ -z "${COMPILER_PACKAGES}" ] ; then
    COMPILER_PACKAGES=$(chroot_exec apt-get -s install g++ make bc | grep "^Inst " | awk -v ORS=" " '{ print $2 }')

    if [ "$RELEASE" = "jessie" ] || [ "$RELEASE" = "stretch" ] || [ "$RELEASE" = "buster" ] ; then
      chroot_exec apt-get -q -y --no-install-recommends install ${COMPILER_PACKAGES}
    fi
  fi
}

chroot_remove_cc() {
  # Remove c/c++ build environment from the chroot
  if [ ! -z "${COMPILER_PACKAGES}" ] ; then
    chroot_exec apt-get -qq -y --auto-remove purge ${COMPILER_PACKAGES}
    COMPILER_PACKAGES=""
  fi
}
