#!/bin/sh

DIR=../data/sqlite-batch-artifact/
NAME=$1

rm -r fillseqbatch fillrandbatch tatp
mkdir fillseqbatch fillrandbatch
rm pgfs/*

cp -r $DIR/*-fillseqbatch fillseqbatch
cp -r $DIR/*-fillrandbatch fillrandbatch
cp -r ../data/sqlite-tatpsls-artifact tatp
