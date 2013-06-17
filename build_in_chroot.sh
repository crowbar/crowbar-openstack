#!/bin/bash
OAT_VERSION_TAG={OAT_VERSION_TAG:-v1.6.0}
git clone git://github.com/OpenAttestation/OpenAttestation.git
cd OpenAttestation
git checkout $OAT_VERSION_TAG
#
cd Source
bash download_jar_packages.sh
bash distribute_jar_packages.sh
cd ../Installer

# cleaning up postinst and postrm
echo > ./DPKG-OAT-Appraiser-Base/DEBIAN/postinst
echo > ./DPKG-OAT-Appraiser-Base/DEBIAN/postrm
# including tests as well
cp -r ../Test/. ./OAT-Appraiser-Configure/

./deb.sh -s /OpenAttestation/Source/

find /tmp/debbuild/DEBS/x86_64/ -type f -name '*.deb' -exec cp '{}' /mnt/current_os/pkgs ';'
