#!/bin/env bash
#
# Builds a Arch Linux live image with ZFS repo created by build-repo.sh
#

set -o errexit
set -o nounset
set -o pipefail

readonly workdir="$(dirname $0)"
readonly archdir="${workdir}/archlive"

cd "${workdir}"
sudo rm -rf "${archdir}"
mkdir "${archdir}"

cp -r /usr/share/archiso/configs/releng/* "${archdir}"

cat <<EOF >> "${archdir}"/pacman.conf
[zfs]
SigLevel = Optional TrustAll
Server = file://$(pwd)/repo
EOF

cat <<EOF >> "${archdir}"/packages.x86_64
linux-headers
zfs-dkms
EOF

cd "${archdir}"
rm -rf out
mkdir out
sudo ./build.sh -v
