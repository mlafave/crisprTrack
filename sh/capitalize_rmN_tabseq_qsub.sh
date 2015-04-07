#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to capitalize and remove N-containing entries from the NGG 20mer
# tabseq file. While this will be used to make the 20mer query FASTA, the main
# use of this specific output is later on, when it's joined to the alignment
# offtarget output.

test_flag kill_flag

PAMTAGSEQ=$1
OUTPUT=$2
KEEP=$3

gunzip -c  ${PAMTAGSEQ} \
	| tr "[:lower:]" "[:upper:]" \
	| awk '$0 !~ /N/' \
	| sed 's/CHR/chr/' \
	| sort -k2,2 \
	| gzip -c \
	> ${OUTPUT}.gz

find_or_flag ${OUTPUT}.gz



exit 0
