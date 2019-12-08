#!/usr/bin/env bash

if [ -z "${UPLOAD_USERNAME}" ]; then
  echo -e "Please enter upload username!"
  exit 255
fi

if [ -z "${UPLOAD_PASSWORD}" ]; then
  echo -e "Please enter upload password!"
  exit 255
fi

BASE_URL="https://bin.dini-mueter.net/repository/public.binary.hosted"
GIT_HASH="$(git log --pretty=format:'%h' -n 1)"

curl -u "${UPLOAD_USERNAME}:${UPLOAD_PASSWORD}" --upload-file "output/disk.img" "${BASE_URL}/levande/trunk/disk-${GIT_HASH}.img"
