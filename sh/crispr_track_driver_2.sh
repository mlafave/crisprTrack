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



BASE=$1



# Unzip the list of 12mer and 20mer positions and sequence
# (${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz), and the count of 12mer
# offtargets (${BASE}_pamlist_12mers_offtargets.gz)

echo "Unzipping 12mer and 20mer input to make a BED file..."

gunzip ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz

test_file ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq


gunzip ${BASE}_pamlist_12mers_offtargets.gz

test_file ${BASE}_pamlist_12mers_offtargets



# merge_12_and_20mers_to_bed.sh is hard-coded to look for files to merge in
# offtarget_20mer_counts/.

echo ""
echo "Concatenating the offtarget 20mer counts, removing 20mers with any offtargets, and using 12mer and 20mer info to make a BED file..."

../sh/merge_12_and_20mers_to_bed.sh \
	${BASE}_pamlist_20mers_noneg_upper_sort.tabseq \
	${BASE}_pamlist_12mers_offtargets \
	${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort

test_file ${BASE}_pamlist_20mer_no20offtarg_noscore_offtargsort.gz



# rm -r offtarget_20mer_counts/



echo ""
echo "Driver 2 Finished."

exit 0

