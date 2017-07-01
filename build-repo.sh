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

    # Version 0.6.5.10
    wget -nv -O "${tmpdir}/zfs-dkms.tar.gz" "${baseurl}/aur-3833b029fc38d499e2b5a7b2c25c2280134ad0f0.tar.gz"
    wget -nv -O "${tmpdir}/spl-dkms.tar.gz" "${baseurl}/aur-74c5db638b2f072e54ff1caef451140bbb94ddc6.tar.gz"

    sha512sum -c <<EOF
7cf86d8281e7862c5125c19f59faf09bc7f43398973a123e6abea57d987b7849521775b2de9ca47c2aafeec793c9c23242bcfec6aef4fe4e20b32f261933e7df  ${tmpdir}/spl-dkms.tar.gz
9e6a3170b6821707657b7a6fc4510c1243ea907c6dfe23485e6c68b98e8195b28e117ba4878ee4bddfe53c143c68f2c8199c9673ed2b2d1acfaa5b183718bad6  ${tmpdir}/zfs-dkms.tar.gz
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
