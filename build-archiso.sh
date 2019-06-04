#!/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

readonly use_dkms=${use_dkms:-0}

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

if [[ $use_dkms == 1 ]]; then

    echo "linux-headers archzfs-dkms" \
         >> "${archdir}"/packages.x86_64

    echo 'echo zfs > /etc/modules-load.d/zfs.conf' \
         >> "${archdir}"/airootfs/root/customize_airootfs.sh
else
    echo "archzfs-linux" >> "${archdir}"/packages.x86_64
fi

# archzfs key
sudo pacman-key --recv-keys F75D9D76
sudo pacman-key --lsign-key F75D9D76

readonly archzfs_gpg=$(pacman-key --export F75D9D76)

cat <<EOF >> "${archdir}"/airootfs/root/customize_airootfs.sh

echo '$archzfs_gpg' > /usr/share/pacman/keyrings/archzfs.gpg

sed -i 's|\[Install\]|ExecStart=/usr/bin/pacman-key --populate archzfs\n\[Install\]|' \
    /etc/systemd/system/pacman-init.service

sed -i 's|\[Install\]|ExecStart=/usr/bin/pacman-key --lsign-key F75D9D76\n\[Install\]|' \
    /etc/systemd/system/pacman-init.service
EOF

rm -rf "${archdir}/out"
mkdir "${archdir}/out"

(cd "${archdir}" && sudo ./build.sh -v)

# Ensure ZFS is installed.
ls "${archdir}"/work/x86_64/airootfs/usr/lib/modules/*/extra/zfs > /dev/null

mv "${archdir}"/out/* "${workdir}"
sudo rm -rf "${archdir}"
