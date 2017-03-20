#!/bin/env bash
#
# Builds a Arch Linux live image with ZFS repo created by build-repo.sh
#

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly workdir="$(dirname $0)"
readonly archdir="${workdir}/archlive"

pacman -Qs archiso > /dev/null || {
    echo "error: archiso is not installed"
    exit 1
}

sudo rm -rf "${archdir}"
mkdir "${archdir}"

cp -r /usr/share/archiso/configs/releng/* "${archdir}"

cat <<EOF >> "${archdir}"/pacman.conf
[zfs]
SigLevel = Optional TrustAll
Server = file://$(realpath "${workdir}")/repo
EOF

cat <<EOF >> "${archdir}"/packages.x86_64
linux-headers
zfs-dkms
EOF

rm -rf "${archdir}/out"
mkdir "${archdir}/out"
(cd "${archdir}" && sudo ./build.sh -v) || exit 1
