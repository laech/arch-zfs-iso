#!/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly workdir="$(dirname $0)"
readonly archdir="${workdir}/archlive"

pacman -Qs archiso > /dev/null || {
    echo "archiso is not installed, installing..."
    sudo pacman --noconfirm -S archiso
}

pacman -Qs archiso > /dev/null || {
    echo "archiso is not installed."
    exit 1
}

sudo rm -rf "${archdir}"
mkdir "${archdir}"

cp -r /usr/share/archiso/configs/releng/* "${archdir}"

cat <<EOF >> "${archdir}"/pacman.conf
[archzfs]
Server = http://archzfs.com/\$repo/x86_64
EOF

cat <<EOF >> "${archdir}"/packages.x86_64
linux-headers
archzfs-dkms
EOF

cat <<EOF >> "${archdir}"/airootfs/root/customize_airootfs.sh
echo zfs > /etc/modules-load.d/zfs.conf
EOF

# archzfs key
sudo pacman-key --recv-keys F75D9D76
sudo pacman-key --lsign-key F75D9D76

rm -rf "${archdir}/out"
mkdir "${archdir}/out"

(cd "${archdir}" && sudo ./build.sh -v)

# Ensure ZFS is installed.
ls "${archdir}"/work/x86_64/airootfs/usr/lib/modules/*/extra/zfs > /dev/null

mv "${archdir}"/out/* "${workdir}"
sudo rm -rf "${archdir}"
