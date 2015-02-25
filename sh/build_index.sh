#!/usr/bin/env bash

source ~/.bashrc

# Fasta input should be a full path
FASTA=$1
OUTPUT=$2

bowtie-build ${FASTA} ${OUTPUT}

exit 0
