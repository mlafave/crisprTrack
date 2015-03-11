#!/usr/bin/env bash

source ~/.bashrc

# Intended to count the number of times each NGG 12mer CRISPR seed matches
# another potential cut site (NGG or NAG) with fewer than two mismatches, not
# counting the site itself.
# --norc is used because the index is built directly from 12mers, so everything
# is effectively on the "same strand".

INDEX=$1
TARGET_FASTA=$2
OUTPUT=$3

gunzip -c ${TARGET_FASTA} \
	| bowtie -t -f -v 1 -a -y --best --norc --sam --sam-nohead \
	${INDEX} \
	- \
	| awk \
	-F "[_\t]" \
	-v OFS="\t" \
	' { a[$11] += $4 }END{ for(var in a){print var"\t"a[var]-1}}' \
	| sort -k1,1 \
	| gzip \
	> ${OUTPUT}.gz


exit 0
