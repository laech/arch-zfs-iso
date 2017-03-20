#!/bin/env bash
#
# Installs zfs-dkms from AUR and creates a local repo.
#

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly workdir="$(dirname $0)"
readonly repodir="${workdir}/repo"
readonly tmpdir="${workdir}/tmp"

ensure_installed() {
    hash "$1" &> /dev/null || {
	echo "error: $1 is not installed"
	exit 1
    }
}

build_zfs() {
    local  baseurl='https://aur.archlinux.org/cgit/aur.git/snapshot'

    rm -rf "${tmpdir}"
    mkdir "${tmpdir}"

    # Version 0.6.5.9-1
    wget -nv -O "${tmpdir}/zfs-dkms.tar.gz" "${baseurl}/aur-8c86abf3c155bcbf6489d43c9c2a91ae463dc025.tar.gz"
    wget -nv -O "${tmpdir}/spl-dkms.tar.gz" "${baseurl}/aur-42b5f8b22efc842cba61bd968a3a7fd722de9a45.tar.gz"

    sha512sum -c <<EOF
7e6873be2c9e98cb27476548245c6bb81477d072d96c54cddb399582f70d828386d7a6ef4b46d1bf4054e25890e2ee4b060cdc42e524810e626b7f8490eece95  ${tmpdir}/spl-dkms.tar.gz
3c2003a3fb0897102a8303d1bc6b2a0e8a7d22cd74281403a5ef715233090a5d8f2e2a692f6497c93e65b58125e359df5c36ece1ee7a44a3cba2160003b7a8fc  ${tmpdir}/zfs-dkms.tar.gz
EOF

    mkdir "${tmpdir}/spl-dkms" && tar -xzvf "${tmpdir}/spl-dkms.tar.gz" -C "${tmpdir}/spl-dkms" --strip-component 1
    mkdir "${tmpdir}/zfs-dkms" && tar -xzvf "${tmpdir}/zfs-dkms.tar.gz" -C "${tmpdir}/zfs-dkms" --strip-component 1

    (cd "${tmpdir}/spl-dkms" && makepkg -i) || exit $?
    (cd "${tmpdir}/zfs-dkms" && makepkg -i) || exit $?
}

create_repo() {
    rm -rf "${repodir}"
    mkdir "${repodir}"
    cp -r "${tmpdir}"/*/*-x86_64.pkg.tar.xz "${repodir}"
    repo-add "${repodir}"/zfs.db.tar.gz "${repodir}"/*.pkg.tar.xz
}

ensure_installed wget
ensure_installed sha512sum
build_zfs
create_repo
rm -rf "${tmpdir}"
