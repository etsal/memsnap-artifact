#!/bin/sh

./table8.py > tmp.tex
cat tmp.tex
pdflatex tmp.tex
mv tmp.pdf pgfs/table8.pdf
rm -r tmp.*
