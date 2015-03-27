#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to perform the necessary actions surrounding the submission of the
# 12mer off-target-counting script. This wrapper waits until the input is
# split, counts the number of input files, and then uses that number to
# determine the number of array jobs. It also keeps track of the job number of
# said array submission, and prints it to a file so subsequent scripts can find
# and use it.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


# Read in input

OUTDIR_PATH=$1
SPLITDIR_PATH=$2 # Use an absolute path
INDEX=$3


# Count the number of split input files

SPLIT_12MER_COUNT=`ls ${SPLITDIR_PATH} | wc -l`


# Submit the array job

ALIGN12MER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-t 1-${SPLIT_12MER_COUNT}:1 \
	-tc 16 \
	../sh/find_12mer_offtargets_array.sh \
	${OUTDIR_PATH} \
	${SPLITDIR_PATH} \
	${INDEX}`

ALIGN12MER_ID=`echo $ALIGN12MER_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

echo "NGG alignment job ID is ${ALIGN12MER_ID}."


# Record that job ID in a file that can be referred to later by the merge step.

echo ${ALIGN12MER_ID} > align_12mer_ID

find_or_flag align_12mer_ID


exit 0
