#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to merge the output of the alignment/offtarget counting,
# specifically when the previous job needed to have its job ID stored in a
# temporary file instead of a variable.


# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


# Read in input

TYPE=$1 # "12mer" or "20mer" - just for record-keeping purposes
ALIGN_ID_FILE=$2
PROCESSEDDIR_PATH=$3
SPLITDIR_PATH=$4
OUTPUT=$5
KEEP=$6


# Capture the job ID of the alignment, and delete the file

ALIGN_ID=`head -1 ${ALIGN_ID_FILE}`

rm ${ALIGN_ID_FILE}


# Submit the merge job

echo "Submitting the ${TYPE} merge job..."

MERGE_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=256M \
	-hold_jid ${ALIGN_ID} \
	../sh/merge.sh \
	${PROCESSEDDIR_PATH} \
	${SPLITDIR_PATH} \
	${OUTPUT} \
	${KEEP}`

MERGE_ID=`echo $MERGE_QSUB | head -1 | cut -d' ' -f3`

echo "${TYPE} merge job ID is ${MERGE_ID}."


# Print the merge job ID to a temporary file

echo ${MERGE_ID} > merge_${TYPE}_ID

exit 0
