#!/usr/bin/env bash

source ~/.bashrc

# Intended to merge the split 20mer offtarget counts, remove those with any
# 20mer offtargets, and produce a BED file by bringing in information on the
# position, sequence, and offtarget count of the 12mers.

PROCESSEDDIR_PATH=$1	# Don't end with a /
TABSEQ_20MERS=$2	# ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq
OFFTARGET_12MERS=$3	# ${BASE}_pamlist_12mers_offtargets
OUTPUT=$4


cat ${PROCESSEDDIR_PATH}/* \
	| gunzip -c \
	| sort -k1,1 \
	| join -1 1 -2 2 - ${TABSEQ_20MERS} \
	| tr "_ " "\t" \
	| sort -k7,7 \
	| join -1 7 -2 1 - ${OFFTARGET_12MERS} \
	| awk -v OFS="\t" '$3 == 0 {print $4,$5,$6,$2,$8,0,$7}' \
	| sort -k5,5n -k1,1 -k2,2n \
	| gzip -c \
	> ${OUTPUT}.gz


exit 0
