#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to merge the files from a given directory into a single gzipped
# file. Also deletes the split and processed directories, unless told
# otherwise. Input files are assumed to be gzipped.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


PROCESSEDDIR_PATH=$1
SPLITDIR_PATH=$2
OUTPUT=$3
KEEP=$4



cat ${PROCESSEDDIR_PATH}/* \
	> ${OUTPUT}.gz


find_or_flag ${OUTPUT}.gz


echo ""
if [ "$KEEP" = "off" ]; then echo "Removing the ${PROCESSEDDIR_PATH} processed directory..."; rm -r ${PROCESSEDDIR_PATH}/; fi
if [ "$KEEP" = "off" ]; then echo "Removing the ${SPLITDIR_PATH} split directory..."; rm -r ${SPLITDIR_PATH}/; fi


exit 0
