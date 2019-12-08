create_sources_list() {
  cat <<EOF > /etc/apt/sources.list
  deb ${MIRROR} ${RELEASE} main restricted universe multiverse
  deb ${MIRROR} ${RELEASE}-security main restricted universe multiverse
  deb ${MIRROR} ${RELEASE}-updates main restricted universe multiverse
EOF
}

set_preseed() {
  cat <<EOF > /tmp/preseed.txt
  grub-pc                grub-pc/install_devices_empty      boolean     true
  grub-pc                grub2/update_nvram                 boolean     false

  keyboard-configuration keyboard-configuration/modelcode   select      pc105
  keyboard-configuration keyboard-configuration/layoutcode  select      ch

  tzdata                 tzdata/Areas                       select      Europe
  tzdata                 tzdata/Zones/Europe                select      Zurich

  locales                locales/locales_to_be_generated    multiselect de_DE.UTF-8 de_CH.UTF-8 de_AT.UTF-8 en_US.UTF-8 en_GB.UTF-8 UTF-8
  locales                locales/default_environment_locale select      en_US.UTF-8
EOF

  debconf-set-selections /tmp/preseed.txt
  rm /tmp/preseed.txt
}

create_sources_list
set_preseed

echo "${HOSTNAME}" > /etc/hostname

apt-get update

apt-get -y install \
  systemd-sysv

dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id

apt-get -y install \
  ubuntu-standard \
  casper \
  lupin-casper \
  discover \
  laptop-detect \
  os-prober \
  network-manager \
  resolvconf \
  net-tools \
  wireless-tools \
  locales \
  ${KERNEL}

apt-get -y install \
  plymouth-theme-ubuntu-logo \
  ubuntu-gnome-desktop \
  ubuntu-gnome-wallpapers

apt-get -y install \
  grub-pc-bin \
  grub-efi-amd64-bin \
  grub2-common

apt-get -y purge \
  gnome-mahjongg \
  gnome-mines \
  gnome-sudoku \
  aisleriot \
  hitori

dpkg-reconfigure locales
dpkg-reconfigure keyboard-configuration
