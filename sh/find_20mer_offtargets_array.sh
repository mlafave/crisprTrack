#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to count all 20mer offtargets for a subset of the NGG 20mers. This
# script is submitted by another script that is created on the fly by the first
# crispr track driver. The awk statement makes an array of aligned sequences as
# keys and the sum of the occurrence of their (off)targeted alignments.

# This is run from within the offtarget_20mer_counts/ directory, which is
# within the working directory.

test_flag kill_flag

OUTDIR_PATH=$1
SPLITDIR_PATH=$2
INDEX=$3



# Task ID counts from 1, but split counts from 0, so need to subtract 1 from
# this value.

NUMBER=`printf "%012d\n" $(( SGE_TASK_ID - 1 ))`


# Because it needs to wait on the -hold_jid, THIS is the point at which one can
# cd into the offtarget_20mer_counts directory. 

cd ${OUTDIR_PATH}


# As of bowtie 1.1.1, if the index ends in an l, you need to explicitly tell
# the aligner that it's a large index.

INDEX_SUBSET=`ls ${INDEX}* | head -1`

if [[ ${INDEX_SUBSET} =~ l$ ]]
then
	BOWTIE_COMMAND='bowtie -t -f -v 2 -m 1 -a -y --best --norc --sam --sam-nohead --large-index'
else
	BOWTIE_COMMAND='bowtie -t -f -v 2 -m 1 -a -y --best --norc --sam --sam-nohead'
fi


${BOWTIE_COMMAND} \
	${INDEX} \
	${SPLITDIR_PATH}/split_${NUMBER} \
	| awk -F"[_\t]" -v OFS="\t" '{ a[$12] += $5 }END{ for(var in a){print var"\t"a[var]-1}}' \
	| sort -k1,1 \
	| gzip -c \
	> split_${NUMBER}_20merofftarg.gz

cd ..

find_or_flag ${OUTDIR_PATH}/split_${NUMBER}_20merofftarg.gz

exit 0
