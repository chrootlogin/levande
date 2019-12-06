truncate -s 0 /etc/machine-id

rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

apt-get -y autoremove
apt-get -y clean

rm -rf ~/.bash_history /var/lib/apt/lists/* /tmp/* /var/tmp/*
