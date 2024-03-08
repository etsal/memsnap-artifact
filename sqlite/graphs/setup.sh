#!/bin/sh

DIR=../data/sqlite-batch-artifact/
NAME=$1

rm -r fillseqbatch fillrandbatch tatp
mkdir fillseqbatch fillrandbatch tatp
rm pgfs/*

cp -r $DIR/*-fillseqbatch fillseqbatch
cp -r $DIR/*-fillrandbatch fillrandbatch
# XXX TATP
#cp -r $DIR/*-fillrandbatch fillrandbatch



