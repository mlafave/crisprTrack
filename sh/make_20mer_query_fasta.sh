#!/usr/bin/env bash

source ~/.bashrc


# Intended to create the 20mer query file from the capitalized, unambiguous NGG
# 20mer tabseq file.
# While this does almost the same job as make_12mer_query_fasta.sh, the 20mer
# version needs to keep the capitalized tabseq version around, so the starting
# files are different. So, while that other script COULD be used for this, it
# would be attempting to do redundant work.

TWENTYMERS=$1
OUTPUT=$2


gunzip -c ${TWENTYMERS} \
	| cut -f2 \
    | sort \
	| uniq -c \
    | awk '{ s++; print ">20merpam"s"_"$1"\n"$2}' \
    > ${OUTPUT}


exit 0
