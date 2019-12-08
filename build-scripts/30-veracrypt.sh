VERACRYPT_URL="https://launchpad.net/veracrypt/trunk/1.24-hotfix1/+download/veracrypt-1.24-Hotfix1-Ubuntu-18.04-amd64.deb"
VERACRYPT_SHA512="4ada5aefe8aae2efdd4b14eaae22f1cc75b1776364a79204bbf916cfd6d4fdeefdaa184a2c9db80a2bef61201affcfcdcab3dff2df4b8f819b893a6f297f5a0c"

wget -q "${VERACRYPT_URL}" -O /tmp/veracrypt.deb
VERACRYPT_DL_SHA512="$(sha512sum /tmp/veracrypt.deb | awk "{print \$1}")"

if [[ "${VERACRYPT_SHA512}" != "${VERACRYPT_DL_SHA512}" ]]; then
  echo -e "Veracrypt-Hash is not correct!"
  exit 255
fi

dpkg -i /tmp/veracrypt.deb

rm -rf /tmp/veracrypt.deb
