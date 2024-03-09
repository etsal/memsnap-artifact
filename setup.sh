#!/bin/sh

# Initialize all the submodules
git submodule update --init aurora-original
git submodule update --init aurora-memsnap
git submodule update --init FlameGraph
git submodule update --init sqlite/auroravfs
git submodule update --init sqlite/sqlite
git submodule update --init sqlite/db_bench
git submodule update --init sqlite/tatp

# Install packages included with this artifact.
cp -r packages /packages

# Set up local variables required for installation and benchmarking
mkdir /testmnt
echo "export MNT=/testmnt" >> ~/.profile
echo "export IGNORE_OSVERSION=\"yes\"" >> ~/.profile

env PACKAGESITE=file:/packages pkg bootstrap
pkg add /packages/Latest/bash-5.2.15.pkg
chsh -s "/usr/local/bin/bash"


for p in `ls /packages/Latest/*.pkg`; 
	do pkg add $p; 
done

# Remove incompatible DTrace definitions
rm /usr/lib/dtrace/psinfo.d
rm /usr/lib/dtrace/ip.d

# Set up bootloader options
mv loader.conf /boot/loader.conf

# Get a base root, required by the benchmarks
wget https://rcs.uwaterloo.ca/~etsal/base.txz
mkdir -p /usr/freebsd-dist
mv base.txz /usr/freebsd-dist

git clone https://github.com/rcslab/aurora-12.3.git
rmdir /usr/src; mv aurora-12.3 /usr/src


mkdir -p /usr/lib/debug/boot/modules/
mkdir -p /usr/aurora/tests/posix/

ln -s /usr/local/bin/python3.9 /usr/local/bin/python
