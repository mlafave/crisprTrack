#!/usr/bin/env bash

source ~/.bashrc

# Intended to identify all NGG and NAG sites in the genome. It aligns the input
# 4-mers, identifies the upstream 12mers, and fetches the sequence of each
# 12mer.

# Index and fasta input should be a full path. $OUTPUT ends up being ${OUTPUT}.gz.
INDEX=$1
TARGET_FASTA=$2
GENOME_FASTA=$3
OUTPUT=$4


bowtie -t -a -v 0 -f -y --sam --sam-nohead \
	${INDEX} \
	${TARGET_FASTA} \
	| awk -v OFS="\t" \
	'$2 == 0 {print $3,$4-12,$4,$10,".","+"} $2 == 16 {print $3,$4+2,$4+14,$10,".","-"}' \
	| awk '$2 >= 0' \
	| sort -k1,1 -k2,2n \
	| bedtools getfasta \
	-s \
	-tab \
	-fi ${GENOME_FASTA} \
	-bed - \
	-fo ${OUTPUT}

gzip ${OUTPUT}

exit 0
