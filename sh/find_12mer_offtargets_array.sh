#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to count the number of times each NGG 12mer CRISPR seed matches
# another potential cut site (NGG or NAG) with fewer than two mismatches, not
# counting the site itself.
# --norc is used because the index is built directly from 12mers, so everything
# is effectively on the "same strand".

test_flag kill_flag

OUTDIR_PATH=$1
SPLITDIR_PATH=$2 # Use an absolute path
INDEX=$3


NUMBER=`printf "%012d\n" $(( SGE_TASK_ID - 1 ))`

cd ${OUTDIR_PATH}


# As of bowtie 1.1.1, if the index ends in an l, you need to explicitly tell
# the aligner that it's a large index.

if [[ ${INDEX} =~ l$ ]]
then
	BOWTIE_COMMAND='bowtie -t -f -v 1 -a -y --best --norc --sam --sam-nohead --large-index'
else
	BOWTIE_COMMAND='bowtie -t -f -v 1 -a -y --best --norc --sam --sam-nohead'
fi


${BOWTIE_COMMAND} \
	${INDEX} \
	${SPLITDIR_PATH}/split_${NUMBER} \
	| awk \
	-F "[_\t]" \
	-v OFS="\t" \
	' { a[$11] += $4 }END{ for(var in a){print var"\t"a[var]-1}}' \
	| sort -k1,1 \
	| gzip -c \
	> split_${NUMBER}_12merofftarg.gz

cd ..

find_or_flag ${OUTDIR_PATH}/split_${NUMBER}_12merofftarg.gz

exit 0
