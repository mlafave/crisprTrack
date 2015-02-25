#!/usr/bin/env bash

source ~/.bashrc

# Intended to combine all 12mers (both NGG and NAG) into a single FASTA file,
# and to indicate how often each 12mer appears as a potential CRISPR target
# site. This FASTA is later used to make the 12mer bowtie index. Note that the
# gzipped files do not need to be gunzipped prior to concatenation.

PAMTAGSEQ=$1
NAGTAGSEQ=$2
OUTPUT=$3

cat ${PAMTAGSEQ} ${NAGTAGSEQ} \
	| gunzip -c \
	| cut -f2 \
	| tr "[:lower:]" "[:upper:]" \
	| sort \
	| uniq -c \
	| awk '{ s++; print ">site"s"_"$1"\n"$2}' \
	| gzip -c \
	> ${OUTPUT}.gz


exit 0
