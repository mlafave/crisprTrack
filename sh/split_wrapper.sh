#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to split a file into smaller files of N lines, in which N is defined
# by the user. Input is expected to be FASTA, so N should be even. The FASTA
# file is assumed to be an absolute path.
# This script is designed to be submitted as a single qsub job, and prepares
# the input for subsequent array qsub jobs.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag



DIRECTORY_NAME=$1 # A name to be used in the new directories created
LINE_COUNT=$2
FASTA=$3
KEEP=$4

if [ `file ${FASTA} | cut -d' ' -f2` == "gzip" ]
then
	echo "Unzipping the input..."
	gunzip ${FASTA}
	FASTA=`echo ${FASTA} | sed 's/.gz$//'`
fi


echo ""
echo "Splitting the input..."

mkdir split_${DIRECTORY_NAME}
cd split_${DIRECTORY_NAME}

../../sh/split_fasta.sh ${LINE_COUNT} ${FASTA}

cd ..

find_or_flag split_${DIRECTORY_NAME}/split_000000000000



echo ""
if [ "$KEEP" = "off" ]; then echo "Removing the unsplit FASTA..."; rm ${FASTA}; fi


# Make a directory in which to put the output of the 20mer alignment
mkdir processed_${DIRECTORY_NAME}



exit 0
