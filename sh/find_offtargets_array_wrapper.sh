#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to perform the necessary actions surrounding the submission of the
# 12mer or 20mer off-target-counting script. This wrapper waits until the input
# is split, counts the number of input files, and then uses that number to
# determine the number of array jobs. It also keeps track of the job number of
# said array submission, and prints it to a file so subsequent scripts can find
# and use it.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


# Read in input

SCRIPT=$1
TYPE=$2 # 12mer or 20mer
OUTDIR_PATH=$3
SPLITDIR_PATH=$4 # Use an absolute path
INDEX=$5


# Count the number of split input files

SPLIT_COUNT=`ls ${SPLITDIR_PATH} | wc -l`


# Submit the array job

ALIGN_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-t 1-${SPLIT_COUNT}:1 \
	-tc 16 \
	${SCRIPT} \
	${OUTDIR_PATH} \
	${SPLITDIR_PATH} \
	${INDEX}`

ALIGN_ID=`echo $ALIGN_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

echo "${TYPE} alignment job ID is ${ALIGN_ID}."


# Record that job ID in a file that can be referred to later by the merge step.

echo ${ALIGN_ID} > align_${TYPE}_ID

find_or_flag align_${TYPE}_ID


exit 0
