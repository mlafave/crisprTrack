#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to run the final steps of the crispr track driver: merging the 20mer
# offtarget output & combining it with 12mer offtarget numbers and tabseq
# positions, creating the BED file, and assigning the BED scores. The point of
# this wrapper is so that part of the driver can be made to wait for the
# relevant previous jobs to finish.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


# Read in input

MERGE_12MER_ID_FILE=$1
ALIGN_20MER_ID_FILE=$2
PROCESSEDDIR_PATH=$3
SPLITDIR_PATH=$4
BASE=$5
NAME=$6
PARENT_JOB_ID=$7
KEEP=$8



# Capture the job ID of the alignment, and delete the file

MERGE_12MER_ID=`head -1 ${MERGE_12MER_ID_FILE}`
rm ${MERGE_12MER_ID_FILE}

ALIGN_20MER_ID=`head -1 ${ALIGN_20MER_ID_FILE}`
rm ${ALIGN_20MER_ID_FILE}



echo "Submitting the end driver job..."


END_DRIVER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${MERGE_12MER_ID},${ALIGN_20MER_ID} \
	../sh/crispr_track_end_driver.sh \
	${PROCESSEDDIR_PATH} \
	${SPLITDIR_PATH} \
	${BASE} \
	${NAME} \
	${PARENT_JOB_ID} \
	${KEEP}`
	
END_DRIVER_ID=`echo $END_DRIVER_QSUB | head -1 | cut -d' ' -f3`

echo "The end driver job ID is ${END_DRIVER_ID}."


exit 0
