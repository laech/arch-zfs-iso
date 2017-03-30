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

#
# Install zfs-dkms, need to explicitly specify linux-headers as it not
# automatically pulled in.
#
cat <<EOF >> "${archdir}"/packages.x86_64
linux-headers
zfs-dkms
EOF

#
# When DKMS tries to install zfs-dkms before spl-dkms, zfs-dkms will error
# with (but doesn't stop the process):
#
#   configure: error:
#           *** Please make sure the kmod spl devel <kernel> package for your
#           *** distribution is installed then try again.  If that fails you
#           *** can specify the location of the spl objects with the
#           *** '--with-spl-obj=PATH' option.
#
# since zfs-dkms depends on spl-dkms. Doing `dkms autoinstall` after DKMS has
# gone through everything include spl-dkms, will get zfs-dkms installed.
#
cat <<EOF >> "${archdir}"/airootfs/root/customize_airootfs.sh
dkms autoinstall
echo zfs > /etc/modules-load.d/zfs.conf
EOF

rm -rf "${archdir}/out"
mkdir "${archdir}/out"
(cd "${archdir}" && sudo ./build.sh -v) || exit 1

mv "${archdir}/out/*" "${workdir}"
sudo rm -rf "${archdir}"
