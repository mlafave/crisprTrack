#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to identify all NGG and NAG sites in the genome. It aligns the input
# 4-mers, identifies the upstream 12mers, and fetches the sequence of each
# 12mer.

test_flag kill_flag

# Index input should be a full path. The output ends up being
# split_${NUMBER}_sites.gz.

OUTDIR_PATH=$1
SPLITDIR_PATH=$2
INDEX=$3
GENOME_FASTA=$4


NUMBER=`printf "%012d\n" $(( SGE_TASK_ID - 1 ))`

# This changes to a directory like NGG_counts, etc.

cd ${OUTDIR_PATH}/


bowtie -t -a -v 0 -f -y --sam --sam-nohead \
	${INDEX} \
	${SPLITDIR_PATH}/split_${NUMBER} \
	| awk -v OFS="\t" \
	'$2 == 0 {print $3,$4-12,$4,$10,".","+"} $2 == 16 {print $3,$4+2,$4+14,$10,".","-"}' \
	| awk '$2 >= 0' \
	| sort -k1,1 -k2,2n \
	| bedtools getfasta \
	-s \
	-tab \
	-fi ${GENOME_FASTA} \
	-bed - \
	-fo split_${NUMBER}_sites

gzip split_${NUMBER}_sites

cd ..

find_or_flag ${OUTDIR_PATH}/split_${NUMBER}_sites.gz

exit 0
