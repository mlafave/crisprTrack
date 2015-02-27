#!/usr/bin/env bash

source ~/.bashrc

# Intended to create a tabseq file of all of the input 20mers. Note this one is
# unusual, in that it expects to receive the gzipped tabseq input from STDIN
# via a pipe. This is so it can easily handle a single file (like NGG only) or
# two at once (like NGG and NAG).

GENOME_FASTA=$1
OUTPUT=$2

gunzip -c \
	| tr "[:lower:]" "[:upper:]" \
	| sed 's/CHR/chr/' \
	| sort -k2,2 \
	| sed 's/(-)/(~)/' \
	| awk \
	-F "[()\t:-]" \
	-v OFS="\t" \
	'{ if($4 == "+"){ if($2-8 >= 0){print $1,$2-8,$3,$1"_"$2-8"_"$3"_"$4"_"$6,"0",$4}}else{print $1,$2,$3+8,$1"_"$2"_"$3+8"_-_"$6,"0","-"}}' \
	| sort -k1,1 -k2,2n \
	| bedtools getfasta \
	-s \
	-name \
	-tab \
    -fi ${GENOME_FASTA} \
    -bed - \
    -fo ${OUTPUT}

gzip ${OUTPUT}


exit 0
