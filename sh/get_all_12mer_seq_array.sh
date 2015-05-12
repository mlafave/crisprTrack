#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to identify all NGG and NAG sites in the genome. It aligns the input
# 4-mers, identifies the upstream 12mers, and fetches the sequence of each
# 12mer.

test_flag kill_flag

# Index input should be a full path. The output ends up being
# split_${NUMBER}_sites.gz.

OUTDIR_PATH=$1
SPLITDIR_PATH=$2
INDEX=$3
GENOME_FASTA=$4
PAM_LENGTH=$5

NUMBER=`printf "%012d\n" $(( SGE_TASK_ID - 1 ))`

# This changes to a directory like NGG_counts, etc.

cd ${OUTDIR_PATH}/

# The offset of the target from the PAM depends on 1) if the PAM takes up the
# entire length of the aligned sequence, and 2) if it doesn't, how much of the
# sequence it does take up. 
# If the substring indicated by the -s option is 4 or greater, the script
# assumes that the PAM takes up the entire length of the aligned sequence. If
# it's less than 4, it assumes that the aligned sequnce is 4 bp long, and the
# PAM bases are the 3'-most bases.

if [ ${PAM_LENGTH} -ge 4 ]
then
	
	# If the PAM takes up the full length of the aligned sequence
	echo "PAM/NAG site is understood to be full-length."
	
	bowtie -t -a -v 0 -f -y --sam --sam-nohead \
		${INDEX} \
		${SPLITDIR_PATH}/split_${NUMBER} \
		| awk -v OFS="\t" \
		-v LENGTH="$PAM_LENGTH" \
		'$2 == 0 {print $3,$4-13,$4-1,$10,".","+"} $2 == 16 {print $3,$4+LENGTH-1,$4+LENGTH+11,$10,".","-"}' \
		| awk '$2 >= 0' \
		| sort -k1,1 -k2,2n \
		| bedtools getfasta \
		-s \
		-tab \
		-fi ${GENOME_FASTA} \
		-bed - \
		-fo split_${NUMBER}_sites

	gzip split_${NUMBER}_sites

else
	
	# If the PAM is only a substring of the aligned sequence
	echo "PAM/NAG site is understood to be a substring of the aligned sequence."

		bowtie -t -a -v 0 -f -y --sam --sam-nohead \
		${INDEX} \
		${SPLITDIR_PATH}/split_${NUMBER} \
		| awk -v OFS="\t" \
		-v LENGTH="$PAM_LENGTH" \
		'$2 == 0 {print $3,$4-9-LENGTH,$4+3-LENGTH,$10,".","+"} $2 == 16 {print $3,$4+LENGTH-1,$4+LENGTH+11,$10,".","-"}' \
		| awk '$2 >= 0' \
		| sort -k1,1 -k2,2n \
		| bedtools getfasta \
		-s \
		-tab \
		-fi ${GENOME_FASTA} \
		-bed - \
		-fo split_${NUMBER}_sites

	gzip split_${NUMBER}_sites
	
fi

cd ..

find_or_flag ${OUTDIR_PATH}/split_${NUMBER}_sites.gz

exit 0
