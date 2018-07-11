#!/bin/bash

set -e

in=$1
out=$2

lines=( 1000000 2000000 10000000 ) 
for n in "${lines[@]}"
do
    outfn="$out/$n-`basename $in`"
    echo "Trimming $n lines from `basename $in` to `basename $outfn`"
    samtools view -h "$in" | head -n $n | samtools view -bS - > "$outfn"
done
