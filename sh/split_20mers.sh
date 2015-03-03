#!/usr/bin/env bash

source ~/.bashrc

# Intended to divide the 20mer NGG query FASTA into manageable chunks. Run from
# within the split_20mer/ directory in the working directory.

LINE_COUNT=$1
PAM_20MER_FASTA=$2


split -a 12 -d -l ${LINE_COUNT} ${PAM_20MER_FASTA} split_


exit 0
