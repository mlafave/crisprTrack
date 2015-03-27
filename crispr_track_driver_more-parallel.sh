#!/usr/bin/env bash

source ~/.bashrc


# Set up functions for file testing & error reporting.
function throw_error
{
	echo >&2 ERROR: $1
	exit 1
}


function test_file
{
	if 
		[ -f $1 ]
	then 
		echo "$1 detected."
	else  
		throw_error "$1 was not detected!"
	fi
}


# function test_variable
# {
# 	if
# 		[ ! $1 ]
# 	then
# 		print_usage
# 		throw_error "required file or option is missing"
# 	fi
# }


function verify_index
{
 if 
   test ! -e $1
 then 
   cd ..
   rmdir $workdir
   throw_error "Bowtie index $1 doesn't exist!"
 elif 
   test ! -s $1
 then 
   cd ..
   rmdir $workdir
   throw_error "Bowtie index $1 is empty!"
 else
   echo "Index $1 verified."
 fi
}



function full_path ()
{
	DIR=`dirname $1`
	FILE=`basename $1`
	PATH="`cd \"$DIR\" 2>/dev/null && pwd -P || echo \"$DIR\"`/$FILE"
	echo $PATH
}



# Input:
# * FASTA of the genome (preferably UCSC, I suppose, if that's where the tracks end up)
# * Name, without spaces, of the working directory. If none given, default to "crisprTrack"


print_usage()
{
  cat <<EOF
Usage: ./crispr_track_driver.sh [options] input_genome.fa
	Options:
	-h	print this help message and exit
	-i	path to the index basename, if available
	-k	keep intermediate files that are deleted by default
	-l	an even number of lines to use per file when aligning 20mers
	-n	name
	-v	print version and quit
EOF
}



print_version()
{
	cat <<EOF
0.2.0
EOF
}


NAME="crisprs"
LINE_COUNT=5000000
KEEP=off

while getopts "hi:kl:n:v" OPTION
do
	case $OPTION in
    	h)
    		print_usage
    		exit 0
    		;;
    	i)
    		INDEX_INPUT=$OPTARG
    		;;
    	k)
    		KEEP=on
    		;;
    	l)
    		LINE_COUNT=$OPTARG
    		;;
    	n)
    		NAME=$OPTARG
    		;;
    	v)
    		print_version
    		exit 0
    		;;
    esac
done
shift $((OPTIND-1))



if [ $(( $LINE_COUNT % 2 )) -ne 0 ]
then 
	throw_error "-l must be an even integer"
elif [ $LINE_COUNT -le 0 ]
then
	throw_error "-l must be greater than 0"
fi 



GENOME_INPUT=$1


# Make sure the input file exists & contains data:

if test ! -f "$1"
then echo "$1 doesn't exist!"
  exit 1
elif test ! -s "$1"
then echo "$1 is empty!"
  exit 1
else
  echo "$1 detected."
fi



# Programs needed:
# * bedtools
# * bowtie

hash bedtools 2>/dev/null || throw_error "bedtools not found"
hash bowtie 2>/dev/null || throw_error "bowtie not found"
hash bowtie-build 2>/dev/null || throw_error "bowtie-build not found"
hash perl 2>/dev/null || throw_error "perl not found"

# convert the input file to an absolute path
GENOME=`full_path $GENOME_INPUT`

# Get the basename without the file extension
BASE=`basename $GENOME | perl -pe 's/\.[^.]+$//i'`


# If an index was provided, get the absolute path of that, too.
if [[ $INDEX_INPUT ]]
then
	FULL_INDEX=`full_path $INDEX_INPUT`
	
	verify_index ${FULL_INDEX}.1.ebwt*
	verify_index ${FULL_INDEX}.2.ebwt*
	verify_index ${FULL_INDEX}.3.ebwt*
	verify_index ${FULL_INDEX}.4.ebwt*
	verify_index ${FULL_INDEX}.rev.1.ebwt*
	verify_index ${FULL_INDEX}.rev.2.ebwt*
	
fi


### If there's a good way to make it so this doesn't need to run in this directory, do it.

# Verify that the name does not have blanks

echo $NAME | grep -q [[:blank:]] && throw_error "'NAME' can't have blanks"


# Make a working directory

PARENT=${PWD}

WORKDIR=$PWD/Workdir_${NAME}_$JOB_ID

if [ -d $WORKDIR ] ; then throw_error "$WORKDIR already exists!"; fi

mkdir $WORKDIR
cd $WORKDIR

mkdir indexes


# If there's already an index provided, just use that. If there isn't, make one
# and put it in the working directory.


if [[ ! $FULL_INDEX ]]
then
	
	echo "Creating an index of the whole FASTA input..."
	cd indexes
	
	../../sh/build_index.sh $GENOME ${BASE}_genomeIndex
		
	FULL_INDEX=${PWD}/${BASE}_genomeIndex
	
	cd ..
	
	verify_index ${FULL_INDEX}.1.ebwt*
	verify_index ${FULL_INDEX}.2.ebwt*
	verify_index ${FULL_INDEX}.3.ebwt*
	verify_index ${FULL_INDEX}.4.ebwt*
	verify_index ${FULL_INDEX}.rev.1.ebwt*
	verify_index ${FULL_INDEX}.rev.2.ebwt*
	
fi



# Prepare to identify all NGG sites in the genome in parallel



echo ""
echo "Splitting the NGG input..."

PAMSPLIT_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	../sh/split_wrapper.sh \
	PAMinput \
	2 \
	${PARENT}/input/pamlist.fa \
	on`

PAMSPLIT_ID=`echo $PAMSPLIT_QSUB | head -1 | cut -d' ' -f3`

echo "PAM split job ID is ${PAMSPLIT_ID}."



echo ""
echo "Identifying all NGG sites & fetching 12mer sequence..."

PAMFIND_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAMSPLIT_ID} \
	-t 1-16:1 \
	-tc 8 \
	../sh/get_all_12mer_seq_array.sh \
	${PWD}/processed_PAMinput \
	${PWD}/split_PAMinput \
	${FULL_INDEX} \
	${GENOME}`

PAMFIND_ID=`echo $PAMFIND_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

echo "NGG alignment job ID is ${PAMFIND_ID}."



# Merge the split files back together

echo ""
echo "Merging the NGG files..."

PAMMERGE_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAMFIND_ID} \
	../sh/merge.sh \
	${PWD}/processed_PAMinput \
	${PWD}/split_PAMinput \
	${BASE}_pamlist_12mers_noneg.tabseq \
	${KEEP}`

PAMMERGE_ID=`echo $PAMMERGE_QSUB | head -1 | cut -d' ' -f3`

echo "PAM merge job ID is ${PAMMERGE_ID}."



# Identify all NGG sites in the genome

# echo ""
# echo "Identifying all NGG sites & fetching 12mer sequence..."
# 
# ../sh/get_all_12mer_seq.sh \
# 	${FULL_INDEX} \
# 	../input/pamlist.fa \
# 	${GENOME} \
# 	${BASE}_pamlist_12mers_noneg.tabseq
# 
# test_file ${BASE}_pamlist_12mers_noneg.tabseq.gz
# 
# 
# # Identify all NAG sites in the genome
# 
# echo ""
# echo "Identifying all NAG sites & fetching 12mer sequence..."
# 
# ../sh/get_all_12mer_seq.sh \
# 	${FULL_INDEX} \
# 	../input/naglist.fa \
# 	${GENOME} \
# 	${BASE}_naglist_12mers_noneg.tabseq
# 
# test_file ${BASE}_naglist_12mers_noneg.tabseq.gz


echo ""
echo "Splitting the NAG input..."

NAGSPLIT_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	../sh/split_wrapper.sh \
	NAGinput \
	2 \
	${PARENT}/input/naglist.fa \
	on`

NAGSPLIT_ID=`echo $NAGSPLIT_QSUB | head -1 | cut -d' ' -f3`

echo "NAG split job ID is ${NAGSPLIT_ID}."



echo ""
echo "Identifying all NAG sites & fetching 12mer sequence..."

NAGFIND_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${NAGSPLIT_ID} \
	-t 1-16:1 \
	-tc 8 \
	../sh/get_all_12mer_seq_array.sh \
	${PWD}/processed_NAGinput \
	${PWD}/split_NAGinput \
	${FULL_INDEX} \
	${GENOME}`

NAGFIND_ID=`echo $NAGFIND_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

echo "NAG alignment job ID is ${NAGFIND_ID}."


# Merge the split files back together

echo ""
echo "Merging the NAG files..."

NAGMERGE_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${NAGFIND_ID} \
	../sh/merge.sh \
	${PWD}/processed_NAGinput \
	${PWD}/split_NAGinput \
	${BASE}_naglist_12mers_noneg.tabseq \
	${KEEP}`

NAGMERGE_ID=`echo $NAGMERGE_QSUB | head -1 | cut -d' ' -f3`

echo "NAG merge job ID is ${NAGMERGE_ID}."



# Make an NGG FASTA file that represents each sequence only once, and that does
# not contain any sequences with ambiguous bases. This file will be used as the
# alignment query; as such, this does not need to be repeated for the NAG
# entires.

echo ""
echo "Making a FASTA file of all NGG-associated 12mers..."
# 
# ../sh/make_12mer_query_fasta.sh \
# 	${BASE}_pamlist_12mers_noneg.tabseq.gz \
# 	${BASE}_pamlist_12mers_noneg_1each_noN.fa
# 
# test_file ${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz


PAM12FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAMMERGE_ID} \
	../sh/make_12mer_query_fasta_qsub.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${BASE}_pamlist_12mers_noneg_1each_noN.fa`

PAM12FASTA_ID=`echo $PAM12FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM 12mer query FASTA job ID is ${PAM12FASTA_ID}."

# Output is ${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz



# Make a FASTA of all NGG and NAG sites, indicating how often each shows up as
# a CRISPR target. This file will be used to make the bowtie index.

echo ""
echo "Making a FASTA file of all NGG- and NAG-associated 12mers..."
# 
# ../sh/make_index_fasta.sh \
# 	${BASE}_pamlist_12mers_noneg.tabseq.gz \
# 	${BASE}_naglist_12mers_noneg.tabseq.gz \
# 	${BASE}_pam_nag_12mercounts_allsites.fa
# 
# test_file ${BASE}_pam_nag_12mercounts_allsites.fa


INDEX12FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAMMERGE_ID},${NAGMERGE_ID} \
	../sh/make_index_fasta_qsub.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${BASE}_naglist_12mers_noneg.tabseq.gz \
	${BASE}_pam_nag_12mercounts_allsites.fa`

INDEX12FASTA_ID=`echo $INDEX12FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 12mer index FASTA job ID is ${INDEX12FASTA_ID}."

# Output is ${BASE}_pam_nag_12mercounts_allsites.fa



# Build the NGG/NAG index in the indexes subdirectory.

echo ""
echo "Making the 12mer index..."

# cd indexes
# 
# ../../sh/build_index.sh ../${BASE}_pam_nag_12mercounts_allsites.fa ${BASE}_pam_nag_12mercounts_allsites
# 
# FULL_12MER_INDEX=${PWD}/${BASE}_pam_nag_12mercounts_allsites
# 
# verify_index ${FULL_12MER_INDEX}.1.ebwt
# verify_index ${FULL_12MER_INDEX}.2.ebwt
# verify_index ${FULL_12MER_INDEX}.3.ebwt
# verify_index ${FULL_12MER_INDEX}.4.ebwt
# verify_index ${FULL_12MER_INDEX}.rev.1.ebwt
# verify_index ${FULL_12MER_INDEX}.rev.2.ebwt
# 
# cd ..
# 
# echo "Deleting the 12mer NGG/NAG FASTA..."
# rm ${BASE}_pam_nag_12mercounts_allsites.fa

MAKE12INDEX_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${INDEX12FASTA_ID} \
	../sh/build_index_wrapper.sh \
	${WORKDIR}/${BASE}_pam_nag_12mercounts_allsites.fa \
	${BASE}_pam_nag_12mercounts_allsites`

MAKE12INDEX_ID=`echo $MAKE12INDEX_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 12mer build-index job ID is ${MAKE12INDEX_ID}."


# Output is ${WORKDIR}/indexes/${BASE}_pam_nag_12mercounts_allsites.1.ebwt,
# etc., unless it ends in .ebwtl



# Map 12mers with bowtie, using -v 1. This detects the number of
# potentially-cutting CRISPRs for which the seed region is fewer than 2
# mismatches different.

# Set the $TYPE variable

TYPE='12mer'

# Split the query FASTA

echo ""
echo "Splitting the NGG 12mer FASTA input..."

SPLIT12MER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAM12FASTA_ID} \
	../sh/split_wrapper.sh \
	12mer \
	${LINE_COUNT} \
	${WORKDIR}/${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz \
	${KEEP}`

SPLIT12MER_ID=`echo $SPLIT12MER_QSUB | head -1 | cut -d' ' -f3`

echo "12mer split job ID is ${SPLIT12MER_ID}."


# Align

echo ""
echo "Counting NGG 12mer offtargets via alignment..."

# ALIGN12MER_QSUB=`qsub \
# 	-cwd \
# 	-V \
# 	-l mem_free=4G \
# 	-hold_jid ${SPLIT12MER_ID},${MAKE12INDEX_ID} \
# 	-t 1-\`ls split_12mer/ | wc -l\`:1 \
# 	-tc 16 \
# 	../sh/find_12mer_offtargets_array.sh \
# 	${WORKDIR}/processed_12mer \
# 	${WORKDIR}/split_12mer \
# 	${WORKDIR}/indexes/${BASE}_pam_nag_12mercounts_allsites`
# 
# ALIGN12MER_ID=`echo $ALIGN12MER_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`
# 
# echo "NGG alignment job ID is ${ALIGN12MER_ID}."


ALIGN12MER_WRAPPER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${SPLIT12MER_ID},${MAKE12INDEX_ID} \
	../sh/find_offtargets_array_wrapper.sh \
	${PARENT}/sh/find_12mer_offtargets_array.sh \
	${TYPE} \
	${WORKDIR}/processed_12mer \
	${WORKDIR}/split_12mer \
	${WORKDIR}/indexes/${BASE}_pam_nag_12mercounts_allsites`

ALIGN12MER_WRAPPER_ID=`echo $ALIGN12MER_WRAPPER_QSUB | head -1 | cut -d' ' -f3`

echo "${TYPE} alignment and counting WRAPPER job ID is ${ALIGN12MER_WRAPPER_ID}."


# Output is ${OUTDIR_PATH}/split_${NUMBER}_12merofftarg.gz



# PAMFIND_QSUB=`qsub \
# 	-cwd \
# 	-V \
# 	-l mem_free=4G \
# 	-hold_jid ${PAMSPLIT_ID} \
# 	-t 1-16:1 \
# 	-tc 8 \
# 	../sh/get_all_12mer_seq_array.sh \
# 	${PWD}/processed_PAMinput \
# 	${PWD}/split_PAMinput \
# 	${FULL_INDEX} \
# 	${GENOME}`



# Merge


echo ""
echo "Counting NGG 12mer offtargets..."

MERGE12MER_WRAPPER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${ALIGN12MER_WRAPPER_ID} \
	../sh/merge_wrapper.sh \
	${TYPE} \
	${WORKDIR}/align_${TYPE}_ID \
	${WORKDIR}/processed_12mer \
	${WORKDIR}/split_12mer \
	${BASE}_pamlist_12mers_offtargets \
	${KEEP}`

MERGE12MER_WRAPPER_ID=`echo $MERGE12MER_WRAPPER_QSUB | head -1 | cut -d' ' -f3`

echo "${TYPE} merge WRAPPER job ID is ${MERGE12MER_WRAPPER_ID}."

# Output is {BASE}_pamlist_12mers_offtargets.gz

# ../sh/find_12mer_offtargets.sh \
# 	${FULL_12MER_INDEX} \
# 	${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz \
# 	${BASE}_pamlist_12mers_offtargets
# 
# test_file ${BASE}_pamlist_12mers_offtargets.gz
# 
# 
# 
# echo "Deleting the FASTA file of all NGG-associated 12mers..."
# rm ${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz



echo ""
echo "Fetching the sequence of all NGG-associated 20mers..."

# cat ${BASE}_pamlist_12mers_noneg.tabseq.gz \
# 	| ../sh/make_20mer_seq.sh \
# 	${GENOME} \
# 	${BASE}_pamlist_20mers_noneg.tabseq
# 
# test_file ${BASE}_pamlist_20mers_noneg.tabseq.gz
# 
# if [ "$KEEP" = "off" ]; then rm ${BASE}_pamlist_12mers_noneg.tabseq.gz; fi

PAM20MERSEQ_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAMMERGE_ID} \
	../sh/make_20mer_seq_qsub.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${GENOME} \
	${BASE}_pamlist_20mers_noneg.tabseq \
	${KEEP}`

PAM20MERSEQ_ID=`echo $PAM20MERSEQ_QSUB | head -1 | cut -d' ' -f3`

echo "PAM 20mer sequence fetch job ID is ${PAM20MERSEQ_ID}."



echo ""
echo "Fetching the sequence of all NAG-associated 20mers..."

# cat ${BASE}_naglist_12mers_noneg.tabseq.gz \
# 	| ../sh/make_20mer_seq.sh \
# 	${GENOME} \
# 	${BASE}_naglist_20mers_noneg.tabseq
# 
# test_file ${BASE}_naglist_20mers_noneg.tabseq.gz
# 
# if [ "$KEEP" = "off" ]; then rm ${BASE}_naglist_12mers_noneg.tabseq.gz; fi

NAG20MERSEQ_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${NAGMERGE_ID} \
	../sh/make_20mer_seq_qsub.sh \
	${BASE}_naglist_12mers_noneg.tabseq.gz \
	${GENOME} \
	${BASE}_naglist_20mers_noneg.tabseq \
	${KEEP}`

NAG20MERSEQ_ID=`echo $NAG20MERSEQ_QSUB | head -1 | cut -d' ' -f3`

echo "NAG 20mer sequence fetch job ID is ${NAG20MERSEQ_ID}."



echo ""
echo "Making a FASTA file of all NGG- and NAG-associated 20mers..."

# ../sh/make_index_fasta.sh \
# 	${BASE}_pamlist_20mers_noneg.tabseq.gz \
# 	${BASE}_naglist_20mers_noneg.tabseq.gz \
# 	${BASE}_pam_nag_20mercounts_allsites.fa
# 
# test_file ${BASE}_pam_nag_20mercounts_allsites.fa
# 
# if [ "$KEEP" = "off" ]; then rm ${BASE}_naglist_20mers_noneg.tabseq.gz; fi


INDEX20FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAM20MERSEQ_ID},${NAG20MERSEQ_ID} \
	../sh/make_index_fasta_qsub.sh \
	${BASE}_pamlist_20mers_noneg.tabseq.gz \
	${BASE}_naglist_20mers_noneg.tabseq.gz \
	${BASE}_pam_nag_20mercounts_allsites.fa`

INDEX20FASTA_ID=`echo $INDEX20FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 20mer index FASTA job ID is ${INDEX20FASTA_ID}."

# Output is ${BASE}_pam_nag_20mercounts_allsites.fa



echo ""
echo "Making the 20mer index..."

# cd indexes/
# 
# ../../sh/build_index.sh ../${BASE}_pam_nag_20mercounts_allsites.fa ${BASE}_pam_nag_20mercounts_allsites
# 
# FULL_20MER_INDEX=${PWD}/${BASE}_pam_nag_20mercounts_allsites
# 
# verify_index ${FULL_20MER_INDEX}.1.ebwt
# verify_index ${FULL_20MER_INDEX}.2.ebwt
# verify_index ${FULL_20MER_INDEX}.3.ebwt
# verify_index ${FULL_20MER_INDEX}.4.ebwt
# verify_index ${FULL_20MER_INDEX}.rev.1.ebwt
# verify_index ${FULL_20MER_INDEX}.rev.2.ebwt
# 
# cd ..
# 
# echo "Deleting the 20mer NGG/NAG FASTA..."
# rm ${BASE}_pam_nag_20mercounts_allsites.fa 



MAKE20INDEX_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${INDEX20FASTA_ID} \
	../sh/build_index_wrapper.sh \
	${WORKDIR}/${BASE}_pam_nag_20mercounts_allsites.fa \
	${BASE}_pam_nag_20mercounts_allsites`

MAKE20INDEX_ID=`echo $MAKE20INDEX_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 20mer build-index job ID is ${MAKE20INDEX_ID}."


echo ""
echo "Done for the time being."
exit 0

############################################################################


echo ""
echo "Removing N-entries from the NGG 20mer tabseq & capitalizing..."

../sh/capitalize_rmN_tabseq.sh \
	${BASE}_pamlist_20mers_noneg.tabseq.gz \
	${BASE}_pamlist_20mers_noneg_upper_sort.tabseq

test_file ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz

if [ "$KEEP" = "off" ]; then rm ${BASE}_pamlist_20mers_noneg.tabseq.gz; fi



echo ""
echo "Making a FASTA file of all NGG-associated 20mers..."

../sh/make_20mer_query_fasta.sh \
	${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz \
	${BASE}_pamlist_20mers_noneg_1each_noN.fa


test_file ${BASE}_pamlist_20mers_noneg_1each_noN.fa



echo ""
echo "Splitting the NGG 20mer FASTA..."

mkdir split_20mer
cd split_20mer

../../sh/split_20mers.sh ${LINE_COUNT} ../${BASE}_pamlist_20mers_noneg_1each_noN.fa

test_file split_000000000000

cd ..



echo ""
echo "Removing the unsplit NGG 20mer FASTA..."
rm ${BASE}_pamlist_20mers_noneg_1each_noN.fa



# Make a directory in which to put the output of the 20mer alignment
mkdir offtarget_20mer_counts



# Count the number of split files
SPLIT_FILE_COUNT=`ls split_20mer/ | wc -l`



echo ""
echo "Submitting the array job directly..."

SECOND_QSUB=`qsub -cwd -V -l mem_free=4G -t 1-${SPLIT_FILE_COUNT}:1 -tc 8 ../sh/find_20mer_offtargets.sh ${PWD} ${FULL_20MER_INDEX}`

SECOND_ID=`echo $SECOND_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

echo "20mer alignment job ID is ${SECOND_ID}."



echo ""
echo "Submitting the merge job directly, held until the array job completes..."

THIRD_QSUB=`qsub -cwd -V -hold_jid ${SECOND_ID} ../sh/crispr_track_driver_2.sh ${BASE} ${NAME} ${JOB_ID} ${KEEP}`

THIRD_ID=`echo $THIRD_QSUB | head -1 | cut -d' ' -f3`

echo "The second driver job ID is ${THIRD_ID}."



echo ""
echo "Array job complete."



echo ""
echo "Driver 1 finished."

exit 0;
