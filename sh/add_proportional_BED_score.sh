#!/usr/bin/env bash

source ~/.bashrc

# Intended to add scores to the intermediate BED file. The scores are highest
# for those with the fewest 12mer offtargets. As the number of offtargets
# increase, the score is reduced proportionally to the total number of entries.
# Entries with the same number of offtargets receive the same score.

SCORELESS_BED=$1
LINECOUNT=$2
OUTPUT=$3


gunzip -c ${SCORELESS_BED} \
	| awk -v COUNT="${LINECOUNT}" -v OFS="\t" 'BEGIN{s = 1000; old5="X"}{ if( $5 == old5){print $1,$2,$3,$4"_"$5,olds,$7}else{print $1,$2,$3,$4"_"$5,s,$7; olds = s}; old5 = $5; s -= 1000/COUNT }' \
	| sort -k1,1 -k2,2n \
	| gzip -c \
	> ${OUTPUT}.gz


exit 0
