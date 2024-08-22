#!/bin/sh

rm -rf sqlite/build
rm -rf tatp/build
cd auroravfs && make clean && cd -
cd db_bench && make clean && cd -
