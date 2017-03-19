#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly tmpdir=$(mktemp -d /tmp/build-zfs-XXXX)
trap "rm -rf ${tmpdir}" EXIT

# Version 0.6.5.9
wget -O "${tmpdir}/zfs-dkms.tar.gz" 'https://aur.archlinux.org/cgit/aur.git/snapshot/aur-8c86abf3c155bcbf6489d43c9c2a91ae463dc025.tar.gz'
wget -O "${tmpdir}/spl-dkms.tar.gz" 'https://aur.archlinux.org/cgit/aur.git/snapshot/aur-42b5f8b22efc842cba61bd968a3a7fd722de9a45.tar.gz'

sha512sum -c <<EOF
7e6873be2c9e98cb27476548245c6bb81477d072d96c54cddb399582f70d828386d7a6ef4b46d1bf4054e25890e2ee4b060cdc42e524810e626b7f8490eece95  spl-dkms.tar.gz
3c2003a3fb0897102a8303d1bc6b2a0e8a7d22cd74281403a5ef715233090a5d8f2e2a692f6497c93e65b58125e359df5c36ece1ee7a44a3cba2160003b7a8fc  zfs-dkms.tar.gz
EOF
