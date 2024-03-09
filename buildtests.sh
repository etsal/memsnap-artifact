#!/bin/sh


cd aurora-memsnap && make -j9 && make install && cd -
cd aurora-original && make -j9 && cd -
cd microbenchmarks && make -j9 && cd -
cd sqlite && ./setup.sh && cd -
cd rocksdb && ./setup.sh && cd -
