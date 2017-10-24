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

    # Version 0.7.3
    wget -nv -O "${tmpdir}/zfs-dkms.tar.gz" "${baseurl}/aur-c0d6f62c9269342f30d87cbfcf5d0a0404eb2f5d.tar.gz"
    wget -nv -O "${tmpdir}/spl-dkms.tar.gz" "${baseurl}/aur-6e69af7e0c638035d242b8a6cf24976a0ceec004.tar.gz"

    sha512sum -c <<EOF
08064d19c52085f28df5d25718f88fa2c34a23a68bf7f5b7fb59069492e34abd5739977798167b95945236c346b8172c161b16953663eccf1cb9fb5926c81a83  ${tmpdir}/spl-dkms.tar.gz
09d05ab217555ca78461e9070b1a35c166d0975f27ef842a20b35ca384f311bc7c1c2137a5a88e3a2fa4721b6406b9b2c92fced9ccb90584cded61bc5c267b3b  ${tmpdir}/zfs-dkms.tar.gz
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
