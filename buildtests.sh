#!/bin/sh

# Initialize all the submodules
git submodule update --init aurora-original
git submodule update --init aurora-memsnap
git submodule update --init FlameGraph
git submodule update --init sqlite/auroravfs
git submodule update --init sqlite/sqlite
git submodule update --init sqlite/db_bench
git submodule update --init sqlite/tatp

cd aurora-memsnap && make -j9 && make install && cd -
cd aurora-original && make -j9 && cd -
cd microbenchmarks && make -j9 && cd -
cd sqlite && ./setup.sh && cd -
cd rocksdb && ./setup.sh && cd -
