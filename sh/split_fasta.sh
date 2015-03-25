#!/usr/bin/env bash

source ~/.bashrc

# Initially intended to divide the 20mer NGG query FASTA into manageable
# chunks, and to be run from within the split_20mer/ directory in the working
# directory. Now it does something similar to whatever FASTA it's presented
# with.

LINE_COUNT=$1
PAM_20MER_FASTA=$2


split -a 12 -d -l ${LINE_COUNT} ${PAM_20MER_FASTA} split_


exit 0
