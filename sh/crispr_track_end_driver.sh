#!/usr/bin/env bash

source ~/.bashrc


# Set up functions for file testing & error reporting.
function throw_error
{
	echo >&2 ERROR: $1
	exit 1
}


function test_file
{
	if 
		[ -f $1 ]
	then 
		echo "$1 detected."
	else  
		throw_error "$1 was not detected!"
	fi
}


# This script will be run from within the working directory, so the paths to
# the other scripts should be the same as driver 1.


# Read in input

PROCESSEDDIR_PATH=$1
SPLITDIR_PATH=$2
BASE=$3
NAME=$4
FIRST_ID=$5
KEEP=$6



echo "This run of the end driver was spawned by job ID ${FIRST_ID}."

if [ "$KEEP" = "off" ]; then rm -r ${SPLITDIR_PATH} ; fi



# Unzip the list of 12mer and 20mer positions and sequence
# (${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz), and the count of 12mer
# offtargets (${BASE}_pamlist_12mers_offtargets.gz)

echo ""
echo "Unzipping 12mer and 20mer input to make a BED file..."

gunzip ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz

test_file ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq


gunzip ${BASE}_pamlist_12mers_offtargets.gz

test_file ${BASE}_pamlist_12mers_offtargets



# merge_12_and_20mers_to_bed.sh is hard-coded to look for files to merge in
# offtarget_20mer_counts/.

echo ""
echo "Concatenating the offtarget 20mer counts, removing 20mers with any offtargets, and using 12mer and 20mer info to make a BED file..."

../sh/merge_12_and_20mers_to_bed_qsub.sh \
	${PROCESSEDDIR_PATH} \
	${BASE}_pamlist_20mers_noneg_upper_sort.tabseq \
	${BASE}_pamlist_12mers_offtargets \
	${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort.bed

test_file ${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort.bed.gz

if [ "$KEEP" = "off" ]; then rm ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq ; else gzip ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq ; fi
if [ "$KEEP" = "off" ]; then rm ${BASE}_pamlist_12mers_offtargets ; else gzip ${BASE}_pamlist_12mers_offtargets ; fi



if [ "$KEEP" = "off" ]; then rm -r ${PROCESSEDDIR_PATH} ; fi



# Count the number of entires in the BED file

echo ""
echo "Counting BED entries..."

LINECOUNT=`gunzip -c ${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort.bed.gz | wc -l`

echo "There are ${LINECOUNT} entries."



# Use the number of entries to adjust the score for each line of the BED file

../sh/add_proportional_BED_score.sh \
	${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort.bed.gz \
	${LINECOUNT} \
	${NAME} \
	${FIRST_ID} \
	${BASE}_pamlist_20mer_no20offtarg_scored.bed

test_file ${BASE}_pamlist_20mer_no20offtarg_scored.bed.gz

if [ "$KEEP" = "off" ]; then rm ${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort.bed.gz ; fi



echo ""
echo "Driver 2 finished."

exit 0

