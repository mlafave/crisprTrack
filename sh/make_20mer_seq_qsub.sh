#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to create a tabseq file of all of the input 20mers.

test_flag kill_flag


# Read in input

TAGSEQ=$1 # ${BASE}_pamlist_12mers_noneg.tabseq.gz, etc.
GENOME_FASTA=$2
OUTPUT=$3
KEEP=$4 # ${BASE}_pamlist_20mers_noneg.tabseq, etc.


# Identify the 20mer spans and fetch the sequence

gunzip -c ${TAGSEQ} \
	| tr "[:lower:]" "[:upper:]" \
	| sed 's/CHR/chr/' \
	| sed 's/(-)/(~)/' \
	| awk \
	-F "[()\t:-]" \
	-v OFS="\t" \
	'{ if($4 == "+"){ if($2-8 >= 0){print $1,$2-8,$3,$1"_"$2-8"_"$3"_"$4"_"$6,"0",$4}}else{print $1,$2,$3+8,$1"_"$2"_"$3+8"_-_"$6,"0","-"}}' \
	| bedtools getfasta \
	-s \
	-name \
	-tab \
    -fi ${GENOME_FASTA} \
    -bed - \
    -fo ${OUTPUT}

gzip ${OUTPUT}

find_or_flag ${OUTPUT}.gz



exit 0
