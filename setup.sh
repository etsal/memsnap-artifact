#!/bin/sh

# Initialize all the submodules
git submodule update --init aurora-original
git submodule update --init aurora-memsnap
git submodule update --init FlameGraph
git submodule update --init sqlite/auroravfs
git submodule update --init sqlite/sqlite
git submodule update --init sqlite/db_bench
git submodule update --init sqlite/tatp

env PACKAGESITE=file:/packages pkg bootstrap

# Install packages included with this artifact.
cp -r packages /packages
pkg add /packages/Latest/bash-5.2.15.pkg
chsh -s "/usr/local/bin/bash"

# Set up local variables required for installation and benchmarking
echo "export IGNORE_OSVERSION=\"yes\"" >> .profile
echo "export MNT=/testmnt" >> .profile

for p in `ls /packages/Latest/*.pkg`; 
	do pkg add $p; 
done

# Remove incompatible DTrace definitions
rm /usr/lib/dtrace/psinfo.d
rm /usr/lib/dtrace/ip.d

git clone git@github.com:etsal/freebsd-aurora.git
rmdir /usr/src; mv freebsd-aurora /usr/src

# Get a base root, required by the benchmarks
wget https://rcs.uwaterloo.ca/~etsal/base.txz
mkdir -p /usr/freebsd-dist
mv base.txz /usr/freebsd-dist

# Note: FreeBSD 12.3 has an issue with building that causes a spurious error caused by a missing "opt_global.h".
# Rerun the above command and eventually it goes away.

echo "WARNING: "
sleep

cd /usr/src; make -j4 NO_CLEAN=yes buildkernel; 
make NO_CLEAN=yes installkernel

# Set up bootloader options
mv loader.conf /boot/loader.conf
