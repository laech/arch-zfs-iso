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
    wget -nv -O "${tmpdir}/zfs-dkms.tar.gz" "${baseurl}/aur-95d950f33543e7201a06fd6fb46499f51ca14909.tar.gz"
    wget -nv -O "${tmpdir}/spl-dkms.tar.gz" "${baseurl}/aur-7223921b0a83173f5eb963419d614cdf59ed6e99.tar.gz"

    sha512sum -c <<EOF
5131953a0c5ffef7d0bc260c132dc19c3372c18d1f5d756c1beaf5773f6fa7d19a059cd54085780aa2b95228b1da72358b25fdf2f7a7d7d3f74d32e19033cc28  ${tmpdir}/spl-dkms.tar.gz
7b9241f627b4a12c6172f2c26caf47db3c9b2a3b456a5945273cd96ff7c312ca9e88fbbb538b1f468991efbf360d599d8e63c6c4c911a99b4cee6dd1eaa50b8c  ${tmpdir}/zfs-dkms.tar.gz
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
