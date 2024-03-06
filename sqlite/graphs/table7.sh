#!/bin/sh

NAME=$1

rm -r fillseqbatch fillrandbatch
rm pgfs/*

mkdir fillseqbatch fillrandbatch
cp -r ../data/$NAME/*-fillseqbatch fillseqbatch
cp -r ../data/$NAME/*-fillrandbatch fillrandbatch
./table7.py > tmp.tex

pdflatex tmp.tex
mv tmp.pdf pgfs/table7.pdf
rm -r tmp.*


