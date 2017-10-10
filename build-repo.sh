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
    wget -nv -O "${tmpdir}/zfs-dkms.tar.gz" "${baseurl}/aur-324493c213ad5046ec9165f59e6238c4629fa12a.tar.gz"
    wget -nv -O "${tmpdir}/spl-dkms.tar.gz" "${baseurl}/aur-d6f7e2bf33121ac88b60bf960556ee1c808064fa.tar.gz"

    sha512sum -c <<EOF
55ccc7d587dce254b69155cef152e58599289ae12f93017a845768d88e886b79f6df85e06fbc07bc427dd39674a64bba6966dc1778c4c48d3bb5161273c18116  ${tmpdir}/spl-dkms.tar.gz
7ace23e00a925f8f5fac1a9ea426398ea5f248829ef247488ed4c4b8fb123ba2494997aabd2cd76bf7d5b8378f71b659a245a77623b764bd40d2506f08eb9caf  ${tmpdir}/zfs-dkms.tar.gz
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
