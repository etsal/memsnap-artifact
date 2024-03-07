#!/bin/sh

cat $1 | grep title | cut -d ' ' -f 1,2,3,4 | sed 's/rect//g' | sed 's/title//g' | sed '/samples/!d' | tr -d ',()<>/' | sort -rnk 2 | head -n 50 
