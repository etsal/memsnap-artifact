#!/bin/sh

# Install packages included with this artifact.
mkdir /packages
cp -r packages /packages/Latest

# Set up local variables required for installation and benchmarking
mkdir /testmnt
echo "export MNT=/testmnt" >> ~/.profile
echo "export IGNORE_OSVERSION=\"yes\"" >> ~/.profile
export IGNORE_OSVERSION=yes

env PACKAGESITE=file:/packages ASSUME_ALWAYS_YES="yes" pkg bootstrap
pkg add /packages/Latest/bash-5.2.15.pkg
chsh -s "/usr/local/bin/bash"

for p in `ls /packages/Latest/*.pkg`; 
	do /bin/sh -c "pkg add $p";
done

# Remove incompatible DTrace definitions
rm /usr/lib/dtrace/psinfo.d
rm /usr/lib/dtrace/ip.d

# Set up bootloader options
cat loader.conf >> /boot/loader.conf

# Get a base root, required by the benchmarks
wget https://rcs.uwaterloo.ca/~etsal/base.txz
mkdir -p /usr/freebsd-dist
mv base.txz /usr/freebsd-dist

rmdir /usr/src;
git clone https://github.com/rcslab/aurora-12.3.git /usr/src

mkdir -p /usr/lib/debug/boot/modules/
mkdir -p /usr/aurora/tests/posix/

ln -s /usr/local/bin/python3.9 /usr/local/bin/python
