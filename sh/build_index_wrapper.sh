#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to create the 12mer or 20mer index.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


INDEX_FASTA=$1	# Use a full path
OUTBASE=$2	# Not a full path, just the name of the file

cd indexes/

../../sh/build_index.sh ${INDEX_FASTA} ${OUTBASE}

# Verify that the index files were created. The asterisk is there in case these
# are .ebwtl files.

find_or_flag ${OUTBASE}.1.ebwt*
find_or_flag ${OUTBASE}.2.ebwt*
find_or_flag ${OUTBASE}.3.ebwt*
find_or_flag ${OUTBASE}.4.ebwt*
find_or_flag ${OUTBASE}.rev.1.ebwt*
find_or_flag ${OUTBASE}.rev.2.ebwt*

cd ..

# Remove the input FASTA.
rm ${INDEX_FASTA}

exit 0
